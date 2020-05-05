set :application, "cap_learning"                          # Đặt tên cho việc deploy
set :repo_url, "git@github.com:lequangcanh/cap_learning.git" # Set repo để lấy code

set :branch, :master                                      # Set branch sẽ sử dụng
set :rvm_type, :user                                      # Set sử dụng rvm
set :pty, true
set :keep_releases, 5                                     # Số lượng phiên bản release tối đa sẽ giữ lại
set :linked_files, %w{.env}                               # Các file sử dụng để liên kết. Các file này được đặt trong thư mục "shared" như nói ở trên
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/upload} # Các thư mục sẽ được sử dụng lại sau mỗi lần deploy
set :bundle_binstubs, nil

set :puma_rackup, -> { File.join(current_path, "config.ru") }
set :puma_state, -> { "#{shared_path}/tmp/pids/puma.state" }
set :puma_pid, -> { "#{shared_path}/tmp/pids/puma.pid" }
set :puma_bind, -> { "unix://#{shared_path}/tmp/sockets/puma.sock" }
set :puma_conf, -> { "#{shared_path}/puma.rb" }
set :puma_access_log, -> { "#{shared_path}/log/puma_access.log" }
set :puma_error_log, -> { "#{shared_path}/log/puma_error.log" }
set :puma_role, :app
set :puma_env, fetch(:rack_env, fetch(:rails_env, "staging"))
set :puma_threads, [0, 8]
set :puma_workers, 0
set :puma_worker_timeout, nil
set :puma_init_active_record, true
set :puma_preload_app, false

set :rvm_ruby_string, :local

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w{publickey}
}

set :tmp_dir, "/tmp/deploy-#{Time.now.to_f}"
