#! /bin/sh

### BEGIN INIT INFO
# Provides:		sshd
# Required-Start:	$remote_fs $syslog
# Required-Stop:	$remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		
# Short-Description:	OpenBSD Secure Shell server
### END INIT INFO

set -e

# /etc/init.d/ssh: start and stop the OpenBSD "secure shell(tm)" daemon

test -x /usr/sbin/sshd || exit 0
( /usr/sbin/sshd -\? 2>&1 | grep -q OpenSSH ) 2>/dev/null || exit 0

umask 022

if test -f /etc/default/ssh; then
    . /etc/default/ssh
fi

. /lib/lsb/init-functions

if [ -n "$2" ]; then
    SSHD_OPTS="$SSHD_OPTS $2"
fi

# Are we running from init?
run_by_init() {
    ([ "$previous" ] && [ "$runlevel" ]) || [ "$runlevel" = S ]
}

check_for_upstart() {
    if init_is_upstart; then
	exit $1
    fi
}

check_for_no_start() {
    # forget it if we're trying to start, and /etc/ssh/sshd_not_to_be_run exists
    if [ -e /etc/ssh/sshd_not_to_be_run ]; then 
	if [ "$1" = log_end_msg ]; then
	    log_end_msg 0 || true
	fi
	if ! run_by_init; then
	    log_action_msg "OpenBSD Secure Shell server not in use (/etc/ssh/sshd_not_to_be_run)" || true
	fi
	exit 0
    fi
}

check_dev_null() {
    if [ ! -c /dev/null ]; then
	if [ "$1" = log_end_msg ]; then
	    log_end_msg 1 || true
	fi
	if ! run_by_init; then
	    log_action_msg "/dev/null is not a character device!" || true
	fi
	exit 1
    fi
}

check_privsep_dir() {
    # Create the PrivSep empty dir if necessary
    if [ ! -d /var/run/sshd ]; then
	mkdir /var/run/sshd
	chmod 0755 /var/run/sshd
    fi
}

check_config() {
    if [ ! -e /etc/ssh/sshd_not_to_be_run ]; then
	/usr/sbin/sshd $SSHD_OPTS -t || exit 1
    fi
}

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

case "$1" in
  start)
	check_for_upstart 1
	check_privsep_dir
	check_for_no_start
	check_dev_null
	log_daemon_msg "Starting OpenBSD Secure Shell server" "sshd" || true
	if start-stop-daemon --start --quiet --oknodo --pidfile /var/run/sshd.pid --exec /usr/sbin/sshd -- $SSHD_OPTS; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;
  stop)
	check_for_upstart 0
	log_daemon_msg "Stopping OpenBSD Secure Shell server" "sshd" || true
	if start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/sshd.pid; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;

  reload|force-reload)
	check_for_upstart 1
	check_for_no_start
	check_config
	log_daemon_msg "Reloading OpenBSD Secure Shell server's configuration" "sshd" || true
	if start-stop-daemon --stop --signal 1 --quiet --oknodo --pidfile /var/run/sshd.pid --exec /usr/sbin/sshd; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;

  restart)
	check_for_upstart 1
	check_privsep_dir
	check_config
	log_daemon_msg "Restarting OpenBSD Secure Shell server" "sshd" || true
	start-stop-daemon --stop --quiet --oknodo --retry 30 --pidfile /var/run/sshd.pid
	check_for_no_start log_end_msg
	check_dev_null log_end_msg
	if start-stop-daemon --start --quiet --oknodo --pidfile /var/run/sshd.pid --exec /usr/sbin/sshd -- $SSHD_OPTS; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;

  try-restart)
	check_for_upstart 1
	check_privsep_dir
	check_config
	log_daemon_msg "Restarting OpenBSD Secure Shell server" "sshd" || true
	RET=0
	start-stop-daemon --stop --quiet --retry 30 --pidfile /var/run/sshd.pid || RET="$?"
	case $RET in
	    0)
		# old daemon stopped
		check_for_no_start log_end_msg
		check_dev_null log_end_msg
		if start-stop-daemon --start --quiet --oknodo --pidfile /var/run/sshd.pid --exec /usr/sbin/sshd -- $SSHD_OPTS; then
		    log_end_msg 0 || true
		else
		    log_end_msg 1 || true
		fi
		;;
	    1)
		# daemon not running
		log_progress_msg "(not running)" || true
		log_end_msg 0 || true
		;;
	    *)
		# failed to stop
		log_progress_msg "(failed to stop)" || true
		log_end_msg 1 || true
		;;
	esac
	;;

  status)
	check_for_upstart 1
	status_of_proc -p /var/run/sshd.pid /usr/sbin/sshd sshd && exit 0 || exit $?
	;;

  *)
	log_action_msg "Usage: /etc/init.d/ssh {start|stop|reload|force-reload|restart|try-restart|status}" || true
	exit 1
esac

exit 0