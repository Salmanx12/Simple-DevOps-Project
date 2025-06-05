Here is an Ansible playbook that meets all your updated requirements for RHEL 7:

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

