#!/bin/bash
# fpm-worker-test.sh: PHP2Shell paths through httpd + php-fpm, compared between builds.
# Run as root in a DISPOSABLE EL8 container or VM with httpd and php-fpm running (it adds a test
# pool and an httpd alias, restarts both and truncates the php-fpm error log) - never on a LIMS host.
# One php-fpm test worker with an 8M memory_limit:
#  A: OOM while parsing a multipart POST (request startup)
#  B: OOM while the script runs: a surviving worker serves the next request with whatever state the
#     bailout left behind (PHP2Shell's cross-request precondition)
#  C: session upload progress (the CVE-2026-109619 path, reachable without session_start()),
#     enabled in the pool on purpose to see whether the handler still runs
set -e
mkdir -p /var/www/oomtest /var/lib/php/sesstest; chown apache: /var/lib/php/sesstest
echo '<?php echo getmypid(), "\n";' > /var/www/oomtest/pid.php
echo '<?php $s = str_repeat("x", 16 * 1024 * 1024); echo strlen($s), "\n";' > /var/www/oomtest/oom.php
cat > /etc/php-fpm.d/oomtest.conf <<'C'
[oomtest]
user = apache
group = apache
listen = /run/php-fpm/oomtest.sock
listen.owner = apache
listen.group = apache
pm = static
pm.max_children = 1
pm.max_requests = 0
php_admin_value[memory_limit] = 8M
php_admin_value[post_max_size] = 1G
php_admin_value[max_input_vars] = 10000000
php_admin_value[max_multipart_body_parts] = 10000000
php_admin_flag[session.upload_progress.enabled] = on
php_admin_flag[session.upload_progress.cleanup] = off
php_admin_value[session.save_path] = /var/lib/php/sesstest
php_admin_flag[session.use_strict_mode] = off
C
cat > /etc/httpd/conf.d/oomtest.conf <<'C'
Alias /oomtest /var/www/oomtest
<Directory /var/www/oomtest>
    Require all granted
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php-fpm/oomtest.sock|fcgi://localhost"
    </FilesMatch>
</Directory>
C
systemctl restart php-fpm httpd
php -r '$b = "--B\r\nContent-Disposition: form-data; name=\"f\"\r\n\r\n" . str_repeat("A", 16 * 1024 * 1024) . "\r\n--B--\r\n"; file_put_contents("/tmp/oom_body", $b);'
echo "$(rpm -q php-fpm)  PHP2Shell CVEs in changelog: $(rpm -q --changelog php-common | grep -c CVE-2026-10961)"
pid() { curl -s http://localhost/oomtest/pid.php; }
same() { [ "$1" = "$2" ] && echo "SAME worker serves the next request" || echo "worker replaced"; }
a=$(pid); code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: multipart/form-data; boundary=B' --data-binary @/tmp/oom_body http://localhost/oomtest/pid.php); sleep 1; b=$(pid)
echo "A multipart OOM:  pid $a -> http $code -> pid $b: $(same "$a" "$b")"
a=$(pid); code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/oomtest/oom.php); sleep 1; b=$(pid)
echo "B script OOM:     pid $a -> http $code -> pid $b: $(same "$a" "$b")"
rm -f /var/lib/php/sesstest/*
printf -- '--B\r\nContent-Disposition: form-data; name="PHP_SESSION_UPLOAD_PROGRESS"\r\n\r\nk\r\n--B\r\nContent-Disposition: form-data; name="up"; filename="x.txt"\r\nContent-Type: text/plain\r\n\r\nhello\r\n--B--\r\n' > /tmp/up_body
code=$(curl -s -o /dev/null -w '%{http_code}' -b 'PHPSESSID=php2shelltest0123456789abcdef' -H 'Content-Type: multipart/form-data; boundary=B' --data-binary @/tmp/up_body http://localhost/oomtest/pid.php)
f=/var/lib/php/sesstest/sess_php2shelltest0123456789abcdef
echo "C upload progress: http $code; session file $( [ -e $f ] && echo "WRITTEN by the progress handler: $(head -c 80 $f)" || echo 'not created (handler did not run)')"
grep -h -E 'oomtest.*(exited|signal)' /var/log/php-fpm/error.log 2>/dev/null | tail -3 || true
rm -f /etc/php-fpm.d/oomtest.conf /etc/httpd/conf.d/oomtest.conf /var/lib/php/sesstest/*; : > /var/log/php-fpm/error.log; systemctl restart php-fpm httpd
