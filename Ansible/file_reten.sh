

---

role - ira - export database for client

name: Database Connectivity and Schema Group Build Play connection: local vars: ira_client_name: "{{ inventory_hostname.split('-') }}" common_region: "{{ lookup('env', 'Customer_Environment') }}{{ ira_client_name[0] }}" Customer_Environment: "{{ common_region }}" job_data_center: "{{ lookup('env', 'JOB_NAME').split('')[0].split('/')[-1] }}" ansible_python_interpreter: 'python' ansible_async_dir: "{{ common_job_workspace }}/.ansible_async" block:

name: Gather Minimum facts setup: gather_subset: min

name: Display App DB export job parameters debug: msg: | common region is {{ common_region }} job_data_center is {{ job_data_center }} inventory_hostname is {{ inventory_hostname }} ira_clients is {{ ira_clients | default('') }} customer_environment is "{{ lookup('env', 'Customer_Environment') }}"

name: Set Data Center database host set_fact: db_oracle_server_host: "{{ lookup('vars', 'db_oracle_server_host_' + job_data_center|lower) }}"

name: Display DB oracle parameters debug: msg: |
db_oracle_server_host is {{ db_oracle_server_host }} db_oracle_server_port is {{ db_oracle_server_port }} db_service_name is {{ db_service_name }} db_schema_list is {{ db_schema_list }} IRA db oracle server host is {{ ira_db_oracle_server_host }}

name: Block to verify database connectivity block:

name: Verify Database connectivity shell: cmd: | export ORACLE_HOME={{ db_oracle_client_home }}; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:{{ db_oracle_client_home }}/lib; {{ db_oracle_sqlplus }} "{{ _conn }}" stdin: "{{ _sql_query }}" vars: _conn: "{{ db_export_user_id }}/{{ db_export_passwd }}@//{{ db_oracle_server_host }}:{{ db_oracle_server_port }}/{{ db_service_name }}" _sql_query: | set heading off EXIT; register: verify_db_connection


always:

name: Display Database Connectivity debug: msg: | Start & End: {{ verify_db_connection.start }} - {{ verify_db_connection.end }}

Result Code: {{ verify_db_connection.rc }}

Stdout:
{{ verify_db_connection.stdout }}

Stderr:
{{ verify_db_connection.stderr }}
_________________________________

name: Write out database connectivity to log copy: dest: "{{ common_job_workspace }}/{{ app_name }}-{{ _client }}-DB-Connectivity-Test-Output-{{ _timestamp }}.log" content: | Command: {{ verify_db_connection.cmd }}

Start & End:
{{ verify_db_connection.start }} - {{ verify_db_connection.end }}

Result Code: {{ verify_db_connection.rc }}

Stdout:
{{ verify_db_connection.stdout }}

Stderr:
{{ verify_db_connection.stderr }}

vars: _timestamp: "{{ '%Y-%m-%d-%H%M%S' | strftime(ansible_date_time.epoch) }}" _client: "{{ inventory_hostname.split('-')[0]| upper }}"


name: Set Application Region Schemas set_fact: common_region_schemas: "{{ common_region_schemas | default([]) + [ (item|dict2items)[0].key ] }}" loop: "{{ db_schema_list }}" loop_control: label: "{{ item }}"

name: Display Application Region Schemas debug: msg: | common_region_schemas are {{ common_region_schemas }}

name: Set Target schemas set_fact: target_schemas: >- {{ target_schema.split(',') if target_schema is defined and target_schema|length > 0 else common_region_schemas }}

name: Show Target Schemas for job debug: msg: | Target schemas are: {{ target_schemas }} run_once: true

name: Perform Schema Export Play block:

name: Perform DB Schema Export shell: cmd: | export ORACLE_HOME={{ db_oracle_client_home }}; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:{{ db_oracle_client_home }}/lib; {{ db_oracle_expdp }} "{{ _conn }}" SCHEMAS={{ item }} DIRECTORY=DUMPDIR DUMPFILE={{ _dumpfile }} LOGFILE={{ _logfile }} CLUSTER={{ db_export_cluster }} PARALLEL={{ db_export_parallel_processes }} COMPRESSION={{ db_export_compression }} vars: _conn: "{{ db_export_user_id }}/{{ db_export_passwd }}@//{{ db_oracle_server_host }}:{{ db_oracle_server_port }}/{{ db_service_name }}" dumpfile: "{{ db_export_group }}{{ item }}schema_Jenkins{{ timestamp }}%U.dmp" logfile: "{{ db_export_group }}{{ item }}schema_Jenkins{{ _timestamp }}.log" _timestamp: "{{ '%Y-%m-%d-%H%M%S' | strftime(ansible_date_time.epoch) }}" throttle: "{{ db_max_parallel_schema_exports | default(2) }}" async: "{{ db_export_runtime_max|int }}" poll: 30 loop: "{{ target_schemas }}" loop_control: label: "Schema: {{ item }}" register: db_schema_export_results


always:

name: Display database schema export results debug: msg: | Start: {{ ira_db_schema.start }} End: {{ ira_db_schema.end }} Result Code: {{ ira_db_schema.rc }} Log file: {{ app_name }}-DB-Schema-{{ ira_db_schema.item }}-Export-{{ _start_timestamp }}.log"

_________________________________

vars: _start_timestamp: "{{ (ira_db_schema.start[:19]|to_datetime).strftime('%Y-%m-%d-%H%M%S') }}" loop: "{{ db_schema_export_results.results }}" loop_control: label: "DB Schema: {{ ira_db_schema.item }}" loop_var: ira_db_schema when:

ira_db_schema.rc == 0


name: Write out database schema export results to log file copy: dest: "{{ common_job_workspace }}/{{ app_name }}-DB-Schema-{{ ira_db_schema_log.item }}-Export-{{ _start_timestamp }}.log" content: | Start & End: {{ ira_db_schema_log.start }} - {{ ira_db_schema_log.end }} Result Code: {{ ira_db_schema_log.rc }}

Command:
{{ ira_db_schema_log.cmd }}

Stdout:
{{ ira_db_schema_log.stdout }}

Stderr:
{{ ira_db_schema_log.stderr }}

vars: _start_timestamp: "{{ (ira_db_schema_log.start[:19]|to_datetime).strftime('%Y-%m-%d-%H%M%S') }}" throttle: 1 loop: "{{ db_schema_export_results.results }}" loop_control: label: "DB Schema Log: {{ ira_db_schema_log.item }}" loop_var: ira_db_schema_log when:

ira_db_schema_log.rc == 0



name: Perform SUNMAPPER DB Export - Table Level Export block:

name: Perform Table Export for SUNMAPPER shell: cmd: | export ORACLE_HOME={{ db_oracle_client_home }}; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:{{ db_oracle_client_home }}/lib; {{ db_oracle_expdp }} "{{ _conn }}" TABLES={{ item }} DIRECTORY=DUMPDIR DUMPFILE={{ _dumpfile }} LOGFILE={{ _logfile }} COMPRESSION={{ db_export_compression }} vars: conn: "{{ db_export_user_id }}/{{ db_export_passwd }}@//{{ db_oracle_server_host }}:{{ db_oracle_server_port }}/{{ db_service_name }}" dumpfile: "SUNMAPPER_DB_EXPORT{{ item }}{{ timestamp }}.dmp" logfile: "SUNMAPPER_DB_EXPORT{{ item }}{{ _timestamp }}.log" _timestamp: "{{ '%Y-%m-%d-%H%M%S' | strftime(ansible_date_time.epoch) }}" loop:

sm_abc

sm_conf

sn_checks

sm_logs

sm_ty loop_control: label: "Table: {{ item }}" register: sunmapper_export_results async: "{{ db_export_runtime_max|int }}" poll: 30



always:

name: Display SUNMAPPER table export results debug: msg: | Table: {{ result.item }} Start: {{ result.start }} End: {{ result.end }} RC: {{ result.rc }} _______________________ loop: "{{ sunmapper_export_results.results }}" loop_control: loop_var: result when: result.rc == 0

name: Write SUNMAPPER table export results to log file copy: dest: "{{ common_job_workspace }}/SUNMAPPER_DB_EXPORT_{{ result.item }}_{{ _timestamp }}.log" content: | Start & End: {{ result.start }} - {{ result.end }} RC: {{ result.rc }}

CMD:
{{ result.cmd }}

STDOUT:
{{ result.stdout }}

STDERR:
{{ result.stderr }}

vars: _timestamp: "{{ (result.start[:19] | to_datetime).strftime('%Y-%m-%d-%H%M%S') }}" loop: "{{ sunmapper_export_results.results }}" loop_control: loop_var: result when: result.rc == 0






























Here’s a LinkedIn post tailored specifically for SRE and DevOps roles after completing your Ansible course:


---

🧵 LinkedIn Post – Ansible Course Completion (SRE/DevOps Focused)

🚀 Just completed a deep dive into Ansible — one more step forward in my SRE/DevOps journey!

This course helped me strengthen critical skills like:

🔹 Automating service deployments
🔹 Managing configurations across environments
🔹 Writing efficient, reusable playbooks and roles
🔹 Integrating with Jenkins, Linux systems, and infrastructure setup
🔹 Improving consistency, reliability, and recovery processes

As someone working in Site Reliability Engineering (SRE) and DevOps, mastering Ansible is essential for ensuring scalable, repeatable, and error-free operations. It's already helping me think more systematically about automation and incident prevention.

📘 Platform: [Pluralsight/Udemy/etc.]
📜 Certification earned ✔

Excited to bring this into real-world use cases like: ➡ Auto-remediation playbooks
➡ Deployment automation
➡ Onboarding environments at scale

Always evolving, always automating.
#SRE #DevOps #Ansible #Automation #InfrastructureAsCode #IaC #Jenkins #Linux #Learning


---

✅ Tips:

Add a certificate or badge image (optional)

Mention real use cases from your job (e.g., Splunk deployment automation)

Tag any mentors or the course platform if relevant


Want help refining this for your specific experience or want a shorter version? I can adjust it.



Here's a professional and engaging LinkedIn post you can use after completing your Ansible course. You can customize it based on your style or experience:


---

🔧 Sample LinkedIn Post – Ansible Course Completion

🚀 Just Completed My Ansible Automation Journey! 🛠️

Excited to share that I’ve successfully completed an in-depth Ansible course on [Platform Name – e.g., Pluralsight/Udemy/etc.].
This has strengthened my skills in:

✅ Infrastructure as Code (IaC)
✅ Automating repetitive tasks
✅ Writing playbooks and roles
✅ Configuring systems at scale
✅ Integrating with Jenkins, Linux, and other DevOps tools

As someone working in [your role or field, e.g., Production Support / SRE / DevOps], learning Ansible has given me a powerful tool to automate deployments, manage configurations, and improve system reliability.

Big thanks to [instructor or platform if you want to tag] for the high-quality content!

🧠 Always learning, always improving.
#ansible #devops #automation #infrastructureascode #linux #sre #learning #career


---

🔁 Optional Additions

📸 Add your certificate screenshot (if available)

📚 Mention real-world use if you’ve already applied it (e.g., “Used it to automate log backups in production”)

👋 Invite others to connect or discuss: “Happy to connect with others exploring Ansible!”


Let me know if you want a shorter, casual version or one tailored to SRE/Cloud/AWS context.




- name: Find files older than 6 days (excluding .zip and .gzip)
  find:
    path: "{{ app_server_log_dir }}"
    age: 6d
    age_stamp: mtime
    excludes:
     - "*.gz"
     - "*.zip"
    file_type: file
    recurse: yes   
  register: old_files

- name: Show list of files to be gzipped
  debug:
    msg: "Displaying 6 days old file: {{ item.path }}"
  loop: "{{ old_files.files }}" 
  loop_control:
    label: "{{ item.path | basename }}"   
  when: old_files.matched > 0 

- name: Show list of files to be gzipped or print if none found
  block:

    - name: Show 6 days old files
      debug:
        msg: "Displaying 6 days old file: {{ item.path }}"
      loop: "{{ old_files.files }}"
      loop_control:
        label: "{{ item.path | basename }}"
      when: old_files.matched > 0

    - name: No files found older than 6 days
      debug:
        msg: "No files found older than 6 days (excluding .gz and .zip)."
      when: old_files.matched == 0
      


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

