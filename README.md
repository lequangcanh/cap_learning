# Some notes

* For run this project, please use this master_key: `152622406a16454360be55bb5ff7d367`

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
state_path "#{project_path}/shared/tmp/pids/puma.state"
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


## Về whenever

Khi deploy với Capistrano, whenever đã hỗ trợ sẵn `whenever/capistrano`. Tuy nhiên, hãy khoan dùng thư viện này, hãy thử tự config để update crontab (sử dụng `whenever --update-crontab`) mỗi lần deploy.

**Vấn đề:** Mỗi lần update crontab thì sẽ sinh ra 1 job tương ứng với phiên bản release. Và cái job tương ứng với phiên bản release cũ sẽ vẫn nằm đó. Điều này có nghĩa là tới giờ chạy cron thì sẽ có n crontab giống nhau cùng chạy.

Vậy thì, việc bây giờ chúng ta sẽ xóa những crontab cũ đi trước khi update crontab. Có 2 cách xóa như sau:

* `crontab -r`: Nhanh gọn dễ xài, dùng trực tiếp lệnh của crontab luôn, hiện tại có bao nhiêu crontab thì xóa hết. Cơ mà ở local thì bạn có thể làm gì bạn muốn chứ lên server không dùng cách này. Vì ngoài những crontab mà chúng ta tạo trong project thì cũng có những crontab khác được sinh ra để theo dõi server.
* `whenever --clear-crontab`: Cái này thì chuẩn bài rồi, nó chỉ xóa những cái crontab được sinh ra bởi whenever thôi.

Bây giờ chúng ta sẽ nhét thêm lệnh `whenever --clear-crontab` trước `whenever --update-crontab` mỗi lần deploy. Deploy thử và những crontab cũ vẫn không bị xóa? Thử access vào server tới thư mục current chạy bằng tay, thì nó chỉ xóa đúng 1 crontab tương ứng với latest release, và sau đó, không có sau đó nữa ....

Hãy xem một số option của whenever:

```bash
whenever --help

Usage: whenever [options]
    -i [identifier],                 Default: full path to schedule.rb file
        --update-crontab
    -w, --write-crontab [identifier] Default: full path to schedule.rb file
    -c, --clear-crontab [identifier]
    -s, --set [variables]            Example: --set 'environment=staging&path=/my/sweet/path'
    -f, --load-file [schedule file]  Default: config/schedule.rb
    -u, --user [user]                Default: current user
    -k, --cut [lines]                Cut lines from the top of the cronfile
    -r, --roles [role1,role2]        Comma-separated list of server roles to generate cron jobs for
    -x, --crontab-command [command]  Default: crontab
    -v, --version
```

Để ý 2 lệnh `--update-crontab` và `--clear-crontab`, ta thấy có cái option `[identifier] - Default: full path to schedule.rb file`. Và chính nó đây rồi, khi ta chạy `whenever --update-crontab` nó sẽ tạo ra 1 crontab với identifier là đường dẫn đến `schedule.rb` của phiên bản release mới nhất. Vậy thì khi deploy phiên bản mới, lệnh `whenever --clear-crontab` sẽ xóa những crontab với identifier là đường dẫn đến `schedule.rb` của phiên bản sắp release, và tất nhiên những crontab cũ nó đang khác identifier thì nó vẫn sẽ nằm đó không xóa được

**Solution** Giải quyết vấn đề trên, lý thuyết chúng ta sẽ có 2 cách:

* Trước khi update crontab, nhảy về folder release cũ, xóa những crontab tương ứng đi
* Đặt cố định 1 cái `identifier` chứ không để default nó sẽ luôn khác nhau giữa các phiên bản release. Đây cũng chính là cách mà `whenever/capistrano` đang làm

  ```ruby
  whenever --update-crontab your_identifier # Update crontab và set identifier
  whenever --clear-crontab your_identifier # Xóa tất cả những crontab có identifier tương ứng
  ```
