- name: Find log files older than 60 days
  find:
    paths: "{{ app_server_log_dir }}"
    age: 60d
    age_stamp: mtime
    patterns: 
      - "*.zip"
      - "*.gz"
      - "*.log"
      - "*.txt"
    recurse: true
  register: old_zip

name: Print message if no old files are found
  debug:
    msg: "No files found older than 60 days."
  when: old_zip.matched == 0
  


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




- name: Find and display non-GZ files
  hosts: localhost
  tasks:
    - name: Find files excluding .gz extensions
      ansible.builtin.find:
        paths: /tmp/archive
        excludes: "*.gz"    # Exclude GZ files
        file_type: file     # Only regular files (not directories)
        recurse: yes        # Search subdirectories
      register: found_files

    - name: Display found files
      ansible.builtin.debug:
        msg: "Found file: {{ item.path }}"
      loop: "{{ found_files.files }}"
      loop_control:
        label: "{{ item.path | basename }}"

You're very close — your playbook currently combines all logs (IRA + Sunmapper) into one single .tar.gz file. But your goal is:

> ✅ Compress IRA logs and Sunmapper logs into separate .tar.gz files,
✅ Then fetch both to your ira_job_workspace.




---

✅ Modified Approach

To achieve your goal, you should:

1. Separate the logs into two lists (IRA and Sunmapper),


2. Create two archive tasks, each using its own file list,


3. Fetch both .tar.gz files separately.




---

🛠️ Updated Playbook Snippet (Only changed/added parts)

# 1. Create list of IRA logs
- name: "Create list of previous {{ ira_log_dump_days }} day(s) of IRA logs"
  find:
    paths: "{{ app_server_log_dir }}"
    recurse: true
    age: "-{{ ira_log_dump_days }}d"
    age_stamp: "mtime"
  register: list_of_ira_logs

# 2. Create list of Sunmapper logs (looped by instance)
- name: "Create list of previous {{ ira_log_dump_days }} day(s) of sunmapper logs"
  find:
    paths: "{{ sunmapper_app_server_log_base_dir }}/{{ item }}"
    recurse: true
    age: "-{{ ira_log_dump_days }}d"
    age_stamp: "mtime"
  register: list_of_sunmapper_logs
  loop: "{{ sunmapper_client_instances }}"

# 3. Combine sunmapper logs into one list
- name: Set Sunmapper log list
  set_fact:
    sunmapper_log_paths: "{{ list_of_sunmapper_logs.results | map(attribute='files') | sum(start=[]) | map(attribute='path') | list }}"

- name: Set IRA log list
  set_fact:
    ira_log_paths: "{{ list_of_ira_logs.files | map(attribute='path') | list }}"


---

🧱 Compress Each Set of Logs Separately

- name: Archive IRA logs
  archive:
    path: "{{ ira_log_paths }}"
    dest: "{{ automation_log_dumps_dir.dest }}/IRA-logs-{{ ansible_date_time.date }}-{{ ansible_date_time.time | replace(':', '') }}.tar.gz"
    owner: "{{ ira_app_user }}"
    group: "{{ ira_app_group }}"
    mode: '0775'
    format: gz
  register: ira_log_gzip_result
  when: ira_log_paths | length > 0

- name: Archive Sunmapper logs
  archive:
    path: "{{ sunmapper_log_paths }}"
    dest: "{{ automation_log_dumps_dir.dest }}/Sunmapper-logs-{{ ansible_date_time.date }}-{{ ansible_date_time.time | replace(':', '') }}.tar.gz"
    owner: "{{ ira_app_user }}"
    group: "{{ ira_app_group }}"
    mode: '0775'
    format: gz
  register: sunmapper_log_gzip_result
  when: sunmapper_log_paths | length > 0


---

📦 Fetch the Archived Files

- name: Fetch IRA log archive to job workspace
  fetch:
    src: "{{ ira_log_gzip_result.dest }}"
    dest: "{{ ira_job_workspace }}/"
    flat: true
  when: ira_log_gzip_result is defined

- name: Fetch Sunmapper log archive to job workspace
  fetch:
    src: "{{ sunmapper_log_gzip_result.dest }}"
    dest: "{{ ira_job_workspace }}/"
    flat: true
  when: sunmapper_log_gzip_result is defined


---

🧹 Optionally Trigger Cleanup Handler

notify:
    - log dump cleanup

Add this under both fetch tasks if cleanup should run regardless of which log type was fetched.


---

✅ Result:

You get:

/.../IRA-logs-2025-06-06-153045.tar.gz

/.../Sunmapper-logs-2025-06-06-153045.tar.gz


Each contains only the relevant logs.

Both are safely fetched to ira_job_workspace.



---

Let me know if you want to include timestamps per log file group or merge per-client Sunmapper logs separately!


Certainly! To combine both fetch tasks into one clean task, you can use a loop and pass both archive result variables as a list. Here's how to do it:


---

✅ Combined Fetch Task for IRA and Sunmapper

- name: Fetch Gzip files from hosts and place in job workspace
  fetch:
    src: "{{ item.dest }}"
    dest: "{{ ira_job_workspace }}/"
    flat: true
  loop:
    - "{{ ira_log_gzip_results }}"
    - "{{ sm_log_gzip_results }}"
  register: fetch_results_combined
  notify:
    - log dump cleanup


---

🧠 Explanation

loop: iterates over both registered result dictionaries.

Each item is one of the registered results (e.g., ira_log_gzip_results, sm_log_gzip_results).

item.dest refers to the path of the gzip file created.

register: fetch_results_combined saves all fetch results in one place, if needed later.



---

This is a clean and scalable approach — if you add more log sources later, you can simply append to the loop list.

Let me know if you want to dynamically handle an undefined result or add conditional checks for presence.




Great question! Let's break this down clearly in the context of how the Ansible archive module and compression work:


---

🔧 What the archive module does:

The archive module in Ansible is used to create compressed tar archives from a set of files or directories.

Syntax (example):

- name: Archive logs with xz compression
  ansible.builtin.archive:
    path:
      - /tmp/file1.gz
      - /tmp/file2.gz
      - /tmp/log1.log
      - /tmp/log2.log
    dest: /tmp/archive.tar.xz
    format: xz


---

🔍 Behavior Explained:

✅ If you include both .gz and .log files:

All four files (*.gz, *.log) will be bundled into one .tar.xz archive (not separate files).

The final output will be something like: /tmp/archive.tar.xz


So:

The existing .gz files are not decompressed or recompressed. They are added "as-is" into the .tar.xz.

The .log files (which are plain text) will be compressed as part of the .tar.xz process.


> 🔸 So yes, the .gz files will not be compressed again, just bundled.

🔸 The .log files will be compressed via xz, inside the .tar.xz.




---

🔄 What You’ll See Inside the Archive:

If you extract /tmp/archive.tar.xz, you'll get:

file1.gz      <-- same original .gz
file2.gz      <-- same original .gz
log1.log      <-- original file, but it was xz-compressed within archive
log2.log      <-- same

But outside the archive, you don’t get individual .tar.gz or .log.tar.gz files.


---

✅ Summary:

File Type	Inside Archive	Compressed Again?	Notes

.gz	As-is	❌ No	Already compressed
.log	xz-compressed	✅ Yes	Compressed as part of .tar.xz



---

Let me know if you’d like a demo playbook or want to try .gz and .log separately in different archives.

