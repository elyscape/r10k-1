require 'git_utils'
require 'r10k_utils'
test_name 'CODEMGMT-86 - C59266 - Attempt to Deploy Environment to Read Only Directory'

#Init
git_repo_path = '/git_repos'
git_repo_name = 'environments'
git_control_remote = File.join(git_repo_path, "#{git_repo_name}.git")
git_environments_path = '/root/environments'
last_commit = git_last_commit(master, git_environments_path)

r10k_config_path = '/etc/r10k.yaml'
r10k_config_bak_path = "#{r10k_config_path}.bak"

tmpfs_path = '/mnt/tmpfs'

#In-line files
r10k_conf = <<-CONF
sources:
  broken:
    basedir: "#{tmpfs_path}"
    remote: "#{git_control_remote}"
CONF

#Verification
error_message_regex = /ERROR\].*Read-only file system/m

#Teardown
teardown do
  step 'Restore Original "r10k" Config'
  on(master, "mv #{r10k_config_bak_path} #{r10k_config_path}")

  step 'Unmount and Destroy TMP File System'
  on(master, "umount #{tmpfs_path}")
  on(master, "rm -rf #{tmpfs_path}")
end

#Setup
step 'Backup Current "r10k" Config'
on(master, "mv #{r10k_config_path} #{r10k_config_bak_path}")

step 'Update the "r10k" Config'
create_remote_file(master, r10k_config_path, r10k_conf)

step 'Create Read Only TMP File System and Mount'
on(master, "mkdir -p #{tmpfs_path}")
on(master, "mount -osize=10m,ro tmpfs #{tmpfs_path} -t tmpfs")

#Tests
step 'Attempt to Deploy via r10k'
on(master, 'r10k deploy environment', :acceptable_exit_codes => 1) do |result|
  assert_match(error_message_regex, result.stderr, 'Expected message not found!')
end
