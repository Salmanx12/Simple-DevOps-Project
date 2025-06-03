- name: Zip old coac files and retain for 60 days
  hosts: "{{ target_hosts if target_hosts is defined and target_hosts|length > 0 else  'all' }}"
  gather_facts: yes
  vars:
    common_dest: /tmp/Coac_Zip_Retention/backup
    directories:
      - src: /tmp/Coac_Zip_Retention/soiFiles
        prefix: soiFiles_backup
        age_days: 5
      - src: /applogs/TSM_SB1_COAC_LGI/pdc9rbsccacap01
        prefix: applogs_backup
        age_days: 2
    retention_days: 60

  tasks:

    - name: Ensure common backup directory exists
      file:
        path: "{{ common_dest }}"
        state: directory
        mode: '0755'

    - name: Find old files to zip from each directory
      find:
        paths: "{{ item.src }}"
        age: "{{ item.age_days }}d"
        file_type: file
        recurse: yes
      loop: "{{ directories }}"
      register: files_to_zip

    - name: Zip old files for each source directory
      vars:
        current_date: "{{ ansible_date_time.date }}"
        current_time: "{{ ansible_date_time.time }}"
      command:
        zip -j {{ common_dest }}/{{ directories[item].prefix }}_{{ current_date }}_{{ current_time }}.zip {{ files_to_zip.results[item].files | map(attribute='path') | join(' ') }}
      loop: "{{ range(0, directories | length) | list }}"
      when: files_to_zip.results[item].files | length > 0
      args:
        creates: "{{ common_dest }}/{{ directories[item].prefix }}_{{ current_date }}_{{ current_time }}.zip"

    - name: Delete original files after zipping - loop over each directory index
      vars:
        loop_index: "{{ item }}"
      loop: "{{ range(0, directories | length | int) | list }}"
      block:
        - name: Delete files found in directory index {{ loop_index }}
          file:
            path: "{{ file_item.path }}"
            state: absent
          loop: "{{ files_to_zip.results[loop_index].files }}"
          loop_control:
            loop_var: file_item

    - name: Change ownership of the zipped file
      file:
        path: "{{ common_dest }}"
        owner: siswebadmin
        group: webadmin-group
        mode: '0755'
        recurse: yes

    - name: Find old zip files for deletion
      find:
        paths: "{{ common_dest }}"
        patterns: "*.zip"
        age: "{{ retention_days }}d"
        recurse: no
      register: old_zips

    - name: Delete zip files older than {{ retention_days }} days
      file:
        path: "{{ item.path }}"
        state: absent
      loop: "{{ old_zips.files }}"
