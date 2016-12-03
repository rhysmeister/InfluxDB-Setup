#!/bin/bash
#set -e; Breaks on Mac :-(
set -u;

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
cat << EOF >> "${HOME}/rhys_influxdb/influxdb1.conf" 
reporting-disabled = false
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
reporting-disabled = false
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

function influx_setup_cluster()
{
	influx_mkdir && echo "Created cluster directory."
	influx_config1 && influx_config2 && echo "Created configuration files";
	influx_launch_nodes && echo "Launched nodes";
	influx_count_processes && echo "Verified correct number of influxd processes running (2).";
}
