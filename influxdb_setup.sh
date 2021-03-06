#!/bin/bash
#set -e; Breaks on Mac :-(
set -u;
#set -x;

GIT_HOME="/Users/rhys1/Documents/github_projects";		# Path to git
if [ -n "$GOPATH" ]; then
	GOPATH="/usr/local/go/bin/";
	if [[ ":$PATH:" == *":/usr/local/go/bin/:"* ]]; then
		PATH="$PATH:$GOPATH";
	fi;
fi;

function influx_remove_dir()
{
	rm -Rf "${HOME}/rhys_influxdb/";
}

function influx_kill()
{
	(pidof influxd) && (pkill influxd);
}

function influx_murder()
{
	influx_kill;
	influx_remove_dir;
}

function influx_mkdir()
{
	mkdir -p "${HOME}/rhys_influxdb/";
}

function influx_config1()
{
cat << EOF > "${HOME}/rhys_influxdb/influxdb1.conf" 
reporting-disabled = true
bind-address = ":8088"

[meta]
  dir = "${HOME}/rhys_influxdb/.influxdb1/meta"
[data]  
  dir = "${HOME}/rhys_influxdb/.influxdb1/data"
  wal-dir = "${HOME}/rhys_influxdb/.influxdb1/wal"
[http]
  enabled = true
  bind-address = ":8086"
  auth-enabled = false  
EOF
}

function influx_config2()
{
cat << EOF >> "${HOME}/rhys_influxdb/influxdb2.conf" 
reporting-disabled = true
bind-address = ":8089"

[meta]
  dir = "${HOME}/rhys_influxdb/.influxdb2/meta"
[data]  
  dir = "${HOME}/rhys_influxdb/.influxdb2/data"
  wal-dir = "${HOME}/rhys_influxdb/.influxdb2/wal"
[http]
  enabled = true
  bind-address = ":8087"
  auth-enabled = false 
EOF
}

function influx_relay_config()
{
cat << EOF >> "${HOME}/rhys_influxdb/influxdb-relay.conf"
[[http]]
# Name of the HTTP server, used for display purposes only.
name = "example-http"

# TCP address to bind to, for HTTP server.
bind-addr = "127.0.0.1:9096"

# Enable HTTPS requests.
ssl-combined-pem = "/etc/ssl/influxdb-relay.pem"

# Array of InfluxDB instances to use as backends for Relay.
output = [
    # name: name of the backend, used for display purposes only.
    # location: full URL of the /write endpoint of the backend
    # timeout: Go-parseable time duration. Fail writes if incomplete in this time.
    # skip-tls-verification: skip verification for HTTPS location. WARNING: it's insecure. Don't use in production.
    { name="local1", location="http://127.0.0.1:8086/write", timeout="10s", buffer-size-mb=100M },
    { name="local2", location="http://127.0.0.1:8087/write", timeout="10s", buffer-size-mb=100M },
]

[[udp]]
# Name of the UDP server, used for display purposes only.
name = "example-udp"

# UDP address to bind to.
bind-addr = "127.0.0.1:9096"

# Socket buffer size for incoming connections.
read-buffer = 0 # default

# Precision to use for timestamps
precision = "n" # Can be n, u, ms, s, m, h
EOF
}

function influx_node1
{
	influxd -config "${HOME}/rhys_influxdb/influxdb1.conf" 2> "${HOME}/rhys_influxdb/influxdb1.log" &
}

function influx_node2
{
	influxd -config "${HOME}/rhys_influxdb/influxdb2.conf" 2> "${HOME}/rhys_influxdb/influxdb2.log" &
}

function influx_launch_nodes()
{
	influx_node1;
	influx_node2;
}

function influx_count_processes()
{
	if [ $(pgrep -x influxd | wc -l) -eq 2 ]; then
		return 0;
	else
		 return 1;
	fi;
}

function influx_run_q()
{
	PORT=${1};
	COMMAND=${2};
	influx --port "$PORT" --execute "$COMMAND";
}

function influx_admin_user()
{
	echo $(openssl rand -base64 8) > "${HOME}/rhys_influxdb/admin_pwd.txt";
	PASS=$(cat "${HOME}/rhys_influxdb/admin_pwd.txt");
	INFLUX_CMD="CREATE USER admin WITH PASSWORD '$PASS' WITH ALL PRIVILEGES";
	sleep 5; # The Influx instance can take a little while to fire up so we wait a little
	influx_run_q 8086 "$INFLUX_CMD" && influx_run_q 8087 "$INFLUX_CMD";
}

function influx_create_test_db()
{
	q="CREATE DATABASE test WITH DURATION 365d NAME duration_365";
	influx_run_q 8086 "$q" && influx_run_q 8087 "$q";
}

function influx_test_db_users()
{
	echo $(openssl rand -base64 8) > "${HOME}/rhys_influxdb/test_ro_pwd.txt";
	RO_PASS=$(cat "${HOME}/rhys_influxdb/test_ro_pwd.txt");
	ro="CREATE USER test_ro WITH PASSWORD '$RO_PASS'";
	echo $(openssl rand -base64 8) > "${HOME}/rhys_influxdb/test_rw_pwd.txt";
	RW_PASS=$(cat "${HOME}/rhys_influxdb/test_rw_pwd.txt");
	rw="CREATE USER test_rw WITH PASSWORD '$RW_PASS'";
	influx_run_q 8086 "$ro" && influx_run_q 8087 "$ro";
	influx_run_q 8086 "$rw" && influx_run_q 8087 "$rw";
}

function influx_test_db_user_perms()
{
	ro="GRANT READ ON test TO test_ro";
	rw="GRANT ALL ON test TO test_rw";
	influx_run_q 8086 "$ro" && influx_run_q 8087 "$ro";
	influx_run_q 8086 "$rw" && influx_run_q 8087 "$rw";
}

function influx_noaa_db_users()
{
	echo $(openssl rand -base64 8) > "${HOME}/rhys_influxdb/noaa_ro_pwd.txt";
	RO_PASS=$(cat "${HOME}/rhys_influxdb/noaa_ro_pwd.txt");
	ro="CREATE USER noaa_ro WITH PASSWORD '$RO_PASS'";
	echo $(openssl rand -base64 8) > "${HOME}/rhys_influxdb/noaa_rw_pwd.txt";
	RW_PASS=$(cat "${HOME}/rhys_influxdb/test_rw_pwd.txt");
	rw="CREATE USER noaa_rw WITH PASSWORD '$RW_PASS'";
	influx_run_q 8086 "$ro" && influx_run_q 8087 "$ro";
	influx_run_q 8086 "$rw" && influx_run_q 8087 "$rw";
}

function influx_noaa_db_user_perms()
{
	ro="GRANT READ ON NOAA_water_database TO noaa_ro";
	rw="GRANT ALL ON NOAA_water_database TO noaa_rw";
	influx_run_q 8086 "$ro" && influx_run_q 8087 "$ro";
	influx_run_q 8086 "$rw" && influx_run_q 8087 "$rw";
}

function influx_curl_sample_data()
{
	if [ ! -f /tmp/NOAA_data.txt ]; then
		curl https://s3-us-west-1.amazonaws.com/noaa.water.database.0.9/NOAA_data.txt > /tmp/NOAA_data.txt;
	fi;
}

function influx_import_file()
{
	influx --port 8086 -database test -import -path=/tmp/NOAA_data.txt -precision=s -username admin -password $(cat "${HOME}/rhys_influxdb/admin_pwd.txt");
	influx --port 8087 -database test -import -path=/tmp/NOAA_data.txt -precision=s -username admin -password $(cat "${HOME}/rhys_influxdb/admin_pwd.txt");
}

function influx_http_auth()
{
	sed -i.bak 's/auth-enabled = false/auth-enabled = true/' "${HOME}/rhys_influxdb/influxdb1.conf";
	sed -i.bak 's/auth-enabled = false/auth-enabled = true/' "${HOME}/rhys_influxdb/influxdb2.conf";
}

function influx_relay_git_clone_pull()
{
	MY_DIR=$(pwd);
	if [ -d "$GIT_HOME/influxdb-relay" ]; then
		cd "$GIT_HOME" && git pull;
	else
		cd "$GIT_HOME";
		git clone https://github.com/influxdata/influxdb-relay.git
	fi;
	cd "$MY_DIR";
}

function influx_setup_cluster()
{
	influx_mkdir && echo "Created cluster directory."
	influx_config1 && influx_config2 && echo "Created configuration files";
	influx_launch_nodes && echo "Launched nodes";
	influx_count_processes && echo "Verified correct number of influxd processes running (2).";
	influx_admin_user && echo "Created admin user on both nodes.";
	influx_create_test_db && echo "Created test database."
	influx_test_db_users && influx_test_db_user_perms && echo "Created test_ro and test_rw users.";
	influx_curl_sample_data && echo "Sample data is ready!";
	influx_import_file && echo "Sample data has been loaded into the NOAA_water_database database.";
	influx_noaa_db_users && influx_noaa_db_user_perms && echo "Created noaa_ro and noaa_rw users.";
	influx_http_auth && echo "Enabled http authentication.";
	influx_kill && influx_launch_nodes && echo "Restarted influx nodes. Logon to node1 with influx -port 8086 -username admin -password \$(cat \"\${HOME}/rhys_influxdb/admin_pwd.txt\")";
	influx_relay_git_clone_pull && echo "InfluxDB-Relay git action executed.";
}
