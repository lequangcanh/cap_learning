# Some notes

## Về puma.rb

* Sử dụng `gem "capistrano3-puma"`
* Tạo file config `puma.rb` trong folder `#{project_path}/shared` để puma đọc config trên file này.

Ví dụ:

```ruby
#!/usr/bin/env puma

directory "#{project_path}/current"
rackup "#{project_path}/current/config.ru"
environment "development"

tag ""

pidfile "#{project_path}/shared/tmp/pids/puma.pid"
state_path "/home/le.quang.canh/LMS-API/shared/tmp/pids/puma.state"
stdout_redirect "#{project_path}/shared/log/puma_access.log", "#{project_path}/shared/log/puma_error.log", true

threads 0,8

bind "unix://#{project_path}/shared/tmp/sockets/puma.sock"

workers 2
daemonize true

prune_bundler


on_restart do
  puts "Refreshing Gemfile"
  ENV["BUNDLE_GEMFILE"] = ""
end
```

## Về sidekiq

* Sử dụng `gem "capistrano-sidekiq"`
* Sidekiq đã remove mode daemonization, logfile and pidfile từ version 6. Vì vậy start/stop bằng bundle exec không còn hợp lý.
* Đổi qua service manager `systemd`. Add các config như sau:

```ruby
# Capfile
require "capistrano/sidekiq"

# config/deploy.rb or config/deploy/#{env}.rb

set :init_system, :systemd # Sử dụng systemd
set :service_unit_name, "sidekiq" # Đọc từ Unit service tên là sidekiq
```

* Trên server thực hiện tạo file service sidekiq như sau:
  * Tạo file `sidekiq.service` theo đường dẫn `/home/${your_user}/.config/systemd/user/sidekiq.service`
  * Nội dung file `sidekiq.service`

    ```
    [Unit]
    Description=${Your description}
    After=syslog.target network.target

    [Service]
    Type=simple
    Environment=RAILS_ENV=${your_project_env}
    WorkingDirectory=${project_path}/current
    ExecStart=/bin/bash -lc 'bundle exec sidekiq -e ${your_project_env}'
    ExecReload=/bin/kill -TSTP $MAINPID
    ExecStop=/bin/kill -TERM $MAINPID

    RestartSec=1
    Restart=on-failure

    SyslogIdentifier=sidekiq

    [Install]
    WantedBy=default.target
    ```

  * Lưu lại và chạy `systemctl --user reenable sidekiq`
  * Restart sidekiq bằng cơm `systemctl --user restart sidekiq`
  * Và sử dụng capistrano `cap production sidekiq:restart`
  * Xem log sidekiq

    ```
    # last 5 days
    journalctl --user-unit sidekiq --since "5 days ago"
    # last hour
    journalctl --user-unit sidekiq --since "1h ago"
    # last 100 lines
    journalctl --user-unit sidekiq -n 100 --no-pager
    # like tail -f
    journalctl --user-unit sidekiq -f
    ```

* **Notes:** Có 1 cách quen thuộc hơn là tạo file system service trong `/etc/systemd/system/sidekiq.service`. Tuy nhiên với cách này chúng ta cần sudo để quản lý service `sudo service sidekiq restart`. Vì vậy nếu dùng cách này sẽ phải bỏ password cho sudo
