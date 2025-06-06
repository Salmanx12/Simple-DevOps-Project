iHere is an Ansible playbook that meets all your updated requirements for RHEL 7:

✅ Requirements Recap
Directory: /applogs
Zip all files older than 6 days using the archive module
Store the .zip in the same directory (/applogs)
Delete the original files after archiving
Apply retention: delete .zip files older than 60 days

✅ Ansible Playbook
---
- name: Zip old logs and apply retention in /applogs
  hosts: all
  become: true
  vars:
    log_dir: /applogs
    zip_name: "logs_{{ ansible_date_time.date }}.zip"
    temp_dir: /tmp/archive_staging

  tasks:

    - name: Create temp directory for zipping
      file:
        path: "{{ temp_dir }}"
        state: directory
        mode: '0755'

    - name: Find files older than 6 days (excluding .zip)
      find:
        paths: "{{ log_dir }}"
        age: 6d
        age_stamp: mtime
        recurse: no
        patterns: '!*zip'
      register: old_files

    - name: Move old files to temp staging dir
      command: mv "{{ item.path }}" "{{ temp_dir }}/"
      loop: "{{ old_files.files }}"
      when: old_files.matched > 0

    - name: Create zip archive from old logs
      archive:
        path: "{{ temp_dir }}"
        dest: "{{ log_dir }}/{{ zip_name }}"
        format: zip
        remove: yes  # delete files after archiving

    - name: Remove temporary staging directory
      file:
        path: "{{ temp_dir }}"
        state: absent

    - name: Find .zip files older than 60 days
      find:
        paths: "{{ log_dir }}"
        age: 60d
        age_stamp: mtime
        patterns: '*.zip'
        recurse: no
      register: old_zips

    - name: Delete .zip files older than 60 days
      file:
        path: "{{ item.path }}"
        state: absent
      loop: "{{ old_zips.files }}"
      when: old_zips.matched > 0


💡 Example Zip File Output:
/applogs/logs_2025-06-05.zip

📌 Notes:
This zips all 6+ day old files into one zip per run.
The archive module does not support zipping each file separately (it works on directories or lists of files).
Using remove: yes inside archive deletes files from the temp directory after compression, not from /applogs directly.

Let me know if you'd prefer one zip file per old file, or want to log actions or email after completion.

To confirm whether the files were really gzipped after running the archive task in Ansible, you can add a debug task and a file existence check using the stat module to verify the gzip archive was created.

Let’s fix and enhance your task step-by-step.


---

✅ Step 1: Fix & Update Your archive Task

- name: Create gzip archive from old logs
  archive:
    path: /tmp/archive
    dest: "{{ app_server_log_dir }}/{{ gzip_name }}"
    format: gz
    owner: "{{ coac_app_user_id }}"
    group: "{{ coac_app_group_id }}"
    mode: '0755'
    remove: yes
  vars:
    gzip_name: "old_logs_{{ ansible_date_time.date }}-{{ inventory_hostname | upper }}.gz"

> 🔧 Note: You had a typo in the extension — changed .gzi to .gz.




---

✅ Step 2: Verify the Gzip File Was Created

- name: Check if gzip file was created
  stat:
    path: "{{ app_server_log_dir }}/{{ gzip_name }}"
  register: gzip_file_stat


---

✅ Step 3: Debug Output to Confirm

- name: Print gzip file creation status
  debug:
    msg: >
      Gzip file was {{ 'successfully created' if gzip_file_stat.stat.exists else 'NOT created' }} at
      {{ app_server_log_dir }}/{{ gzip_name }}


---

✅ Optional: Print File Size

- name: Show gzip file size (if created)
  debug:
    msg: "Gzip file size: {{ gzip_file_stat.stat.size | default('N/A') }} bytes"
  when: gzip_file_stat.stat.exists


---

✅ Output Summary:

This sequence will:

Create a .gz file from /tmp/archive

Delete the original files

Check if the .gz file was created

Print whether the file exists and its size


Let me know if you'd also like to log this to a file or email a summary post-run.



- name: Print list of successfully gzipped files
  debug:
    msg: "Compressed: {{ item.dest }}"
  loop: "{{ gzip_results.results | selectattr('rc', 'equalto', 0) | map(attribute='invocation.module_args') | list }}"
  when: gzip_results is defined

  - name: Find files excluding .zip and .gz
  find:
    paths: /your/path
    recurse: yes
    use_regex: yes
    patterns: '^(?!.*\.(zip|gz)$).*'
  register: found_files


  - name: Print successfully gzipped files
  debug:
    msg: "Gzipped: {{ item.dest | default('unknown') }}"
  loop: >-
    {{ gzip_results.results
       | selectattr('rc', 'defined')
       | selectattr('rc', 'equalto', 0)
       | list }}
  when: gzip_results is defined

  - name: "Create list of previous {{ ira_log_dump_days }} day(s) of IRA logs"
  find:
    paths: "{{ app_server_log_dir }}"
    recurse: true
    age: "-{{ ira_log_dump_days }}d"
    age_stamp: "mtime"
  register: list_of_ira_logs

- name: "Create list of previous {{ ira_log_dump_days }} day(s) of sunmapper logs"
  find:
    paths: "{{ sunmapper_app_server_log_base_dir }}/{{ item }}"
    recurse: true
    age: "-{{ ira_log_dump_days }}d"
    age_stamp: "mtime"
  register: list_of_sunmapper_logs
  loop: "{{ sunmapper_client_instances }}"

- name: create list of files
  set_fact:
    list_of_logs: "{{ list_of_ira_logs.files | map(attribute='path') |list }}"

- name: add sunmapper log files to list of files
  set_fact:
    list_of_logs: "{{ list_of_logs }}  + {{ item.files | map(attribute='path') | list }}"
  loop: "{{ list_of_sunmapper_logs.results }}"

- name: Display list of log files that will be zipped (lvl 1)
  debug:
    msg: "{{ _list }}"
    verbosity: 1
  vars:
    _list: "{{ list_of_logs }}"

- name: Ensure log dumps dir exists and has correct permissions
  file:
    name: "{{ automation_log_dumps_dir.dest }}"
    state: directory
    owner: "{{ ira_app_user }}"
    group: "{{ ira_app_group }}"
    mode: 00775
    recurse: true


- name: "Create .tar.gz archive of the previous {{ ira_log_dump_days }} day(s) of logs"
  archive:
    path: "{{ _list }}"
    dest: "{{ automation_log_dumps_dir.dest }}/{{ _gzip_file }}"
    owner: "{{ ira_app_user }}"
    group: "{{ ira_app_group }}"
    mode: 0775
    format: gz
  vars:
    _list: "{{ list_of_logs | list }}"
    _gzip_file: "{{ ansible_date_time.date }}-{{ (ansible_date_time.time).replace(':','') }}-{{ inventory_hostname|upper }}-logs.tar.gz"
  register: log_gzip_results

- name: Fetch zip file from hosts and place in job workspace
  fetch:
    src: "{{ log_gzip_results.dest }}"
    dest: "{{ ira_job_workspace }}/"
    flat: true
  register: fetch_results
  notify:
    - log dump cleanup


  
  

