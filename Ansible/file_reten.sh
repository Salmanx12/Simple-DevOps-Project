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
    dest: "{{ automation_log_dumps_dir.dest }}/{{ _zip_file }}"
    owner: "{{ ira_app_user }}"
    group: "{{ ira_app_group }}"
    mode: 0775
    format: gz
  vars:
    _list: "{{ list_of_logs | list }}"
    _zip_file: "{{ ansible_date_time.date }}-{{ (ansible_date_time.time).replace(':','') }}-{{ inventory_hostname|upper }}-logs.tar.gz"
  register: log_zip_results

- name: Fetch zip file from hosts and place in job workspace
  fetch:
    src: "{{ log_zip_results.dest }}"
    dest: "{{ ira_job_workspace }}/"
    flat: true
  register: fetch_results
  notify:
    - log dump cleanup
