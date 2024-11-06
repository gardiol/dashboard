#!/bin/bash

declare -A TEMPLATE_COLS
declare -A TEMPLATE_TITLE
declare -A SERVICES_PIDS
declare -A MOUNTPOINTS
declare -A WIDGETS

source monitor.conf

######
# The CPU elaboration calculations require a daemon running in the backgroud, which we do not have,
# so this part is currently commented out. It's kept here in case in the future it might be useful.
#function calculate_cpu()
#{
#sleepDurationSeconds=1
#
## read cpu stats to arrays
#readarray -t previousStats < <( awk '/^cpu /{flag=1}/^intr/{flag=0}flag' /proc/stat )
#sleep $sleepDurationSeconds
#readarray -t currentStats < <( awk '/^cpu /{flag=1}/^intr/{flag=0}flag' /proc/stat )
#
## loop through the arrays
#for i in "${!previousStats[@]}"; do
#  # Break up arrays 1 line sting into an array element for each item in string
#  previousStat_elemant_array=(${previousStats[i]})
#  currentStat_elemant_array=(${currentStats[i]})
#
#  # Get all columns from user to steal
#  previousStat_colums="${previousStat_elemant_array[@]:1:7}"
#  currentStat_colums="${currentStat_elemant_array[@]:1:7}"
#
#  # Replace the column seperator (space) with +
#  previous_cpu_sum=$((${previousStat_colums// /+}))
#  current_cpu_sum=$((${currentStat_colums// /+}))
#
#  # Get the delta between two reads
#  cpu_delta=$((current_cpu_sum - previous_cpu_sum)) 
#
#  # Get the idle time Delta
#  cpu_idle=$((currentStat_elemant_array[4]- previousStat_elemant_array[4]))
#
#  # Calc time spent working
#  cpu_used=$((cpu_delta - cpu_idle)) 
#
#  # Calc percentage
#  cpu_usage=$((100 * cpu_used / cpu_delta))
#
#  # Get cpu used for calc cpu percentage used
#  cpu_used_for_calc="${currentStat_elemant_array[0]}"
#
#  if [[ "$cpu_used_for_calc" == "cpu" ]]; then
#    export CPU_TOT="$cpu_usage"
#    echo "total: "$cpu_usage"%"
#  else
#    echo $cpu_used_for_calc": "$cpu_usage"%"
#  fi
#done
#}

#
# Parse /proc/loadavg and extract Load Average for last 1min, 5min and 15min
#
# Output: 
#  - AVG_1  = average for last 1  minute
#  - AVG_5  = average for last 5  minute
#  - AVG_15 = average for last 15 minute
#
function parse_loadavg()
{
	local data=($(cat /proc/loadavg))
	export AVG_1=${data[0]}
	export AVG_5=${data[1]}
	export AVG_15=${data[2]}
}

#
# Parse mountpoint and extract filesystem usage
# Input:
#  - $1 = mount point
# Output:
#  - MP_OK  = 0(exist) / 1(not exist) mount point exist or not (filesystem mounted) 
#  - MP_DEV = mount point device
#  - MP_TOT = filesystem total size in bytes
#  - MP_USE = filesystem used size in bytes
#  - MP_FRE = filesystem free size in bytes
#  - MP_PER = filesystem usage percentage
#
function parse_mountpoint()
{
	local mp=$1
	local data=($(df "${mp}" | grep "${mp}"))
	export MP_OK=$?
	export MP_DEV=${data[0]}
	export MP_TOT=${data[1]}
	export MP_USE=${data[2]}
	export MP_FRE=${data[3]}
	local tmp=${data[4]}
	export MP_PER=${tmp%%%}
}

#
# Parse /proc/meminfo to extract memory and cache usage
# Output:
#  - MEM_TOT  = total RAM (MemTotal)
#  - MEM_FRE  = free RAM (MemFree)
#  - MEM_AVA  = available RAM (MemAvailable)
#  - SWAP_TOT = total SWAP (SwapTotal)
#  - SWAP_FRE = free SWAP (SwapFree)
#
function parse_meminfo()
{
	local mem_info=$(</proc/meminfo)
	local tmp=${mem_info#*MemTotal:[[:blank:]]}
	export MEM_TOT=${tmp%%[[:space:]]kB*}
	local tmp=${mem_info#*MemFree:[[:blank:]]}
	export MEM_FRE=${tmp%%[[:space:]]kB*}
	local tmp=${mem_info#*MemAvailable:[[:blank:]]}
	export MEM_AVA=${tmp%%[[:space:]]kB*}
	local tmp=${mem_info#*SwapTotal:[[:blank:]]}
	export SWAP_TOT=${tmp%%[[:space:]]kB*}
	local tmp=${mem_info#*SwapFree:[[:blank:]]}
	export SWAP_FRE=${tmp%%[[:space:]]kB*}
}

#
# Check if a PID maps to a running process by checking /proc/<PID>/status
# Input:
#  - $1 = PID to check
# Output:
#  - PID_RUN  = 0(running) / 1(not running)
#  - PID_NAME = pid's name as written in the status file
#
function parse_pidstatus()
{
	local pid=$1
	export PID_RUN=1
	export PID_NAME=
	if [ -e "/proc/${pid}/status" ]
	then
		local status=$(</proc/${pid}/status)
		status="${status#*Name:[[:blank:]]}"
		export PID_NAME=${status%%[[:space:]]*Umask*}
		export PID_RUN=0
	fi
}

#
# Perform a ping on a host/ip
# Input:
#  - $1 = host/ip to ping
#  - $2 = number of pings
# Output:
#  - PING_OK = 0(ok) / 1(failed)
#  - RTT_MIN = miminum RTT time
#  - RTT_AVG = average RTT time
#  - RTT_MAX = maximum RTT time
#
function ping_test()
{
	local dest=$1
	local npings=$2
	local ping_out # setting local ping_out = $(...) will result in $? always to be 0!
	ping_out=$(ping -n -q -c ${npings} -W 0.2 ${dest} 2> /dev/null)
	export PING_OK=$?
	local tmp=${ping_out##*tt min/avg/max/mdev =}
	tmp=${tmp%[[:blank:]]ms*}
	tmp=(${tmp//\// })
	export RTT_MIN=${tmp[0]}
	export RTT_AVG=${tmp[1]}
	export RTT_MAX=${tmp[2]}
}

#
# Test ISP connectivity
# Input:
#  - $1 = gateway IP (don't use hostname! This is your ISP router IP)
#  - $2 = destination IP to test for actual internet connectivity (don't use hostname! And use external IP)
# Output:
#  - GATEWAY_TEST = 0(gateway reachable) / 1(gateway unreachable)
#  - DESTINATION_TEST = 0(internet reachable) / 1(internet unreachable)
#
function connectivity_test()
{
	local gateway=$1
	local destination=$2
	# Test ISP
	ping_test ${gateway} 1
	export GATEWAY_TEST=${PING_OK}
	export DESTINATION_TEST=1
	if [ ${PING_OK} -eq 0 ]
	then
		ping_test ${destination} 1
		export DESTINATION_TEST=${PING_OK}
	fi
}

#
# Print a template enclosed in common HTML/CSS
# Args:
#  - 1: template name
#  - 2: config key
# Input Config Variables:
#  - TEMPLATE_COLS  = conlumns for this config_key
#  - TEMPLATE_TITLE = title to display
# Output Template variables:
#  - COLUMNS = number of columns
#
function print_template()
{
	test -z ${TEMPLATE_COLS[$2]} && ${TEMPLATE_COLS[$2]}=1
	local TEMPLATE=$1
	local COLUMNS=${TEMPLATE_COLS[$2]}
	local TITLE=${TEMPLATE_TITLE[$2]}
	echo "<div class='monitor_box'>"
	source "templates/${TEMPLATE}.sh"
	echo "</div>"
}

# 
# Display connectivity status
# Templates:
#  - templates/connectivity.sh 
# Input Config variables:
#  - UPLINKS = array of uplink ISPs in the format: name:gateway:destination name:gateway:destination ...
# Output Template variables:
#  - NUM_ISPS        = number of total isps (arrays size)
#  - ISP_NAME        = array of host names
#  - ISP_GW_CLASS    = array of ping results, 0(ping ok) 1(ping failed)
#  - ISP_GW_STATUS   = array of ping results, 0(ping ok) 1(ping failed)
#  - ISP_DEST_CLASS  = array of classes (ok for STATUS=0 and ko for STATUS=1)
#  - ISP_DEST_STATUS = array of classes (ok for STATUS=0 and ko for STATUS=1)
#
function print_connectivity()
{
	local NUM_ISPS=0
	local ISP_NAME=()
	local ISP_GW_CLASS=()
	local ISP_GW_STATUS=()
	local ISP_DEST_CLASS=()
	local ISP_DEST_STATUS=()

	for isp in ${UPLINKS}
	do
		ISP_NAME[${NUM_ISPS}]=${isp%%:*}
		local gw_dest=${isp#*:}
		local gw=${gw_dest%%:*}
		local dest=${gw_dest##*:}
		connectivity_test ${gw} ${dest}
		ISP_GW_STATUS[${NUM_ISPS}]=${GATEWAY_TEST}
		if [ ${ISP_GW_STATUS[${NUM_ISPS}]} -eq 0 ]
		then
			ISP_GW_CLASS[${NUM_ISPS}]="ok"
		else
			ISP_GW_CLASS[${NUM_ISPS}]="ko"
		fi
		ISP_DEST_STATUS[${NUM_ISPS}]=${DESTINATION_TEST}
		if [ ${ISP_DEST_STATUS[${NUM_ISPS}]} -eq 0 ]
		then
			ISP_DEST_CLASS[${NUM_ISPS}]="ok"
		else
			ISP_DEST_CLASS[${NUM_ISPS}]="ko"
		fi
		NUM_ISPS=$(( NUM_ISPS+1 ))
	done
	print_template "connectivity" $1
}

# 
# Display ping status
# Args:
#  - $1: config key
# Templates:
#  - templates/ping.sh 
# Input Config variables:
#  - PINGS = list of hosts to ping = name:destination name:destination ...
# Output Template variables:
#  - PING_NUM     = number of total hosts (arrays size)
#  - PING_HOSTS   = array of host names
#  - PING_STATUS  = array of ping results, 0(ping ok) 1(ping failed)
#  - PING_CLASS   = array of classes (ok for STATUS=0 and ko for STATUS=1)
#  - PING_RTT_MIN = array of minimum RTTs
#  - PING_RTT_AVG = array of average RTTs
#  - PING_RTT_MAX = array of maximum RTTs
#
function print_pings()
{
	local PING_NUM=0
	local PING_HOSTS=()
	local PING_STATUS=()
	local PING_RTT_MIN=()
	local PING_RTT_AVG=()
	local PING_RTT_MAX=()
	[ -z ${PINGS[$1]} ] && PINGS[$1]=${PINGS}
	for p in ${PINGS[$1]}
	do
		PING_HOSTS[${PING_NUM}]=${p%:*}
		ping_test ${p#*:} 1
		PING_STATUS[${PING_NUM}]=${PING_OK}
		if [ ${PING_OK} -eq 0 ]
		then 
			PING_CLASS[${PING_NUM}]="ok"
		else
			PING_CLASS[${PING_NUM}]="ko"
		fi
		PING_RTT_MIN[${PING_NUM}]=${RTT_MIN}
		PING_RTT_AVG[${PING_NUM}]=${RTT_MIN}
		PING_RTT_MIN[${PING_NUM}]=${RTT_MIN}
		PING_NUM=$(( PING_NUM+1 ))
	done
	print_template "ping" $1
}

#
# Print TOP information
# Args:
#  - $1: config key
# Templates:
#  - templates/top.sh 
# Input Config variables:
#  - TOP_CPU_LIMIT = value in % above which the task will be KO instead of OK
#  - TOP_TASKS_LIMIT   = maximum number of tasks to parse  (unset or for unlimited)
# Output Template variables:
# - NUM_TASKS     = number or tasks (following are all arrays)
# - TASKS_CPU_PER = array of sorted %cpu
# - TASKS_MEM_PER = array of sorted %mem
# - TASKS_PID     = array of pid of task
# - TASKS_CMD     = array of task executable
# - TASKS_CLASS   = array of classes
# - TASKS_USER    = array of users
#
function print_top()
{
	local NUM_TASKS=0
	local TASKS_CPU_PER=()
	local TASKS_MEM_PER=()
	local TASKS_PID=()
	local TASKS_CMD=()
	local TASKS_CLASS=()
	local row=
	[ -z ${TOP_TASKS_LIMIT[$1]} ] && TOP_TASKS_LIMIT[$1]=${TOP_TASKS_LIMIT}
	if [ -z ${TOP_TASKS_LIMIT[$1]} -o ${TOP_TASKS_LIMIT[$1]} -eq 0 ]
	then
		TOP_TASKS_LIMIT=99999
	fi
	if [ -z ${TOP_CPU_LIMIT} ]
	then
		TOP_CPU_LIMIT=100
	fi
	while read -r row
	do
		local task=(${row})
		if [ ${NUM_TASKS} -lt ${TOP_TASKS_LIMIT[$1]} ]
		then
			TASKS_CPU_PER[${NUM_TASKS}]=${task[0]}
			local cpu_integer=${TASKS_CPU_PER[${NUM_TASKS}]%%.*}
			if [ ${cpu_integer} -gt ${TOP_CPU_LIMIT} ]
				TASKS_CLASS[${NUM_TASKS}]="ko"
			then
				TASKS_CLASS[${NUM_TASKS}]="ok"
			fi
			TASKS_MEM_PER[${NUM_TASKS}]=${task[1]}
			TASKS_USER[${NUM_TASKS}]=${task[2]}
			TASKS_PID[${NUM_TASKS}]=${task[3]}
			TASKS_CMD[${NUM_TASKS}]=${task[4]}
			NUM_TASKS=$(( NUM_TASKS+1 ))
		fi
	done < <(ps -e --no-headers -o %cpu,%mem,user,pid,comm --sort -%cpu -ww)
	print_template "top" $1
}

# 
# Display mountpoints and filesystems data
# Args:
#  - $1: config key
# Templates:
#  - templates/mounts.sh
# Input Config variables:
#  - MOUNTPOINTS      = list of mounts, format: name:mountpoint name:mountpoint ...
#  - FILESYSTEM_LIMIT = percentage above which "ko" class is used instead of "ok" class
# Output Template variables:
#  - NUM_MOUNTS   = number of mounts (size of arrays)
#  - MOUNT_NAME   = array of service names
#  - MOUNT_CLASS  = class for service (ok if running, ko if not running) (array)
#  - MOUNT_DEV    = mount device  (array)
#  - MOUNT_PER    = filesystem used percentage (array)
#  - MOUNT_TOT    = filesystem size in kilobytes (array)
#  - MOUNT_TOT_MB = filesystem size in megabytes (array)
#  - MOUNT_TOT_GB = filesystem size in gigabytes (array)
#  - MOUNT_USE    = filesystem used in kilobytes (array)
#  - MOUNT_USE_MB = filesystem used in megabytes (array)
#  - MOUNT_USE_GB = filesystem used in gigabytes (array)
#  - MOUNT_FRE    = filesystem free in kilobytes (array)
#  - MOUNT_FRE_MB = filesystem free in megabytes (array)
#  - MOUNT_FRE_GB = filesystem free in gigabytes (array)
#
function print_mounts()
{
	local NUM_MOUNTS=0
	local MOUNT_NAME=()
	local MOUNT_CLASS=()
	local MOUNT_DEV=()
	local MOUNT_PER=()
	local MOUNT_TOT=()
	local MOUNT_USE=()
	local MOUNT_FRE=()
	local MOUNT_TOT_MB=()
	local MOUNT_USE_MB=()
	local MOUNT_FRE_MB=()
	local MOUNT_TOT_GB=()
	local MOUNT_USE_GB=()
	local MOUNT_FRE_GB=()

	test "${MOUNTPOINTS[$1]}" = "" && MOUNTPOINTS[$1]=${MOUNTPOINTS}
	for mp in ${MOUNTPOINTS[$1]}
	do
		MOUNT_NAME[${NUM_MOUNTS}]=${mp%%:*}
		parse_mountpoint "${mp##*:}"
		MOUNT_CLASS[${NUM_MOUNTS}]="ko"
		if [ ${MP_OK} -eq 0 ]
		then
			MOUNT_DEV[${NUM_MOUNTS}]=${MP_DEV}
			MOUNT_PER[${NUM_MOUNTS}]=${MP_PER%%%}
			MOUNT_TOT[${NUM_MOUNTS}]=${MP_TOT}
			MOUNT_TOT_MB[${NUM_MOUNTS}]=$(( MP_TOT/1024 )).$(( MP_TOT%1024+10 ))
			MOUNT_TOT_GB[${NUM_MOUNTS}]=$(( MP_TOT/1024/1024 )).$(( MP_TOT/1024%1024+10 ))
			MOUNT_USE[${NUM_MOUNTS}]=${MP_USE}
			MOUNT_USE_MB[${NUM_MOUNTS}]=$(( MP_USE/1024 )).$(( MP_USE%1024+10 ))
			MOUNT_USE_GB[${NUM_MOUNTS}]=$(( MP_USE/1024/1024 )).$(( MP_USE/1024%1024+10 ))
			MOUNT_FRE[${NUM_MOUNTS}]=${MP_FRE}
			MOUNT_FRE_MB[${NUM_MOUNTS}]=$(( MP_FRE/1024 )).$(( MP_FRE%1024+10 ))
			MOUNT_FRE_GB[${NUM_MOUNTS}]=$(( MP_FRE/1024/1024 )).$(( MP_FRE/1024%1024+10 ))

			if [ ${MOUNT_PER[${NUM_MOUNTS}]} -lt ${FILESYSTEM_LIMIT} ]
			then
				MOUNT_CLASS[${NUM_MOUNTS}]="ok"
			fi
		fi
		NUM_MOUNTS=$(( NUM_MOUNTS+1 ))
	done
	print_template "mounts" $1
}

# 
# Display services/processes status
# Args:
#  - $1: config key
# Templates:
#  - templates/services.sh
# Input Config variables:
#  - SERVICES_PIDS = list of services, format: name:pidfile name:pidfile ... Defaults to $SERVICES_PIDS if SERVICES_PIDS[config_key] is missing
#  - SERVICES_COLS = how many columns to split the services (number)
# Output Template variables:
#  - COLUMNS        = number of columns to split on
#  - NUM_SERVICES   = number of services (size of arrays)
#  - SERVICE_NAMES  = array of service names
#  - SERVICE_CLASS  = class for service (ok if running, ko if not running)
#  - SERVICE_STATUS = 0(service is running) 1(service not running)
#  - SERVICE_PID    = PID of service
#
function print_services()
{
	local NUM_SERVICES=0
	local SERVICE_NAMES=()
	local SERVICE_CLASS=()
	local SERVICE_STATUS=()
	local SERVICE_PID=()
	test "${SERVICES_PIDS[$1]}" = "" && SERVICES_PIDS[$1]=${SERVICES_PIDS}
	for service in ${SERVICES_PIDS[$1]}
	do
		name=${service%%:*}
		pid_file=${service##*:}
		SERVICE_NAMES[${NUM_SERVICES}]="${name}"
		PID_RUN=1
		if [ -e ${pid_file} ]
		then
			SERVICE_PID[${NUM_SERVICES}]=$(<${pid_file})
			if [ -n "${SERVICE_PID[${NUM_SERVICES}]}" ]
			then
				parse_pidstatus ${SERVICE_PID[${NUM_SERVICES}]}
			else
				SERVICE_PID[${NUM_SERVICES}]=0
			fi
		else
			SERVICE_PID[${NUM_SERVICES}]=0
		fi
		SERVICE_STATUS[${NUM_SERVICES}]=${PID_RUN}
		if [ ${PID_RUN} -eq 0 ]
		then
			SERVICE_CLASS[${NUM_SERVICES}]="ok"
		else
			SERVICE_CLASS[${NUM_SERVICES}]="ko"
		fi
		NUM_SERVICES=$(( NUM_SERVICES+1 ))
	done
	print_template "services" $1
}


# 
# Display system Load averages
# Templates:
#  - templates/load.sh
# Input Config variables:
#  - LOAD_MIN = minimum value of load to show with class=ok
#  - LOAD_MAX = maximum value of load to show with class=ok
#  (will use class=avg otherwise)
# Output Template variables:
#  - AVG_1        = last minute load average
#  - AVG_1_CLASS  = class to be used for last minute
#  - AVG_5        = last 5 minutes load average
#  - AVG_5_CLASS  = class to be used for last 5 minutes
#  - AVG_15       = last 15 minutes load average
#  - AVG_15_CLASS = class to be used for last 15 minutes
#
function print_load()
{
	parse_loadavg
	local AVG_1_CLASS="avg"
	local AVG_5_CLASS="avg"
	local AVG_15_CLASS="avg"
	test ${AVG_1%%.*} -gt ${LOAD_MAX} && AVG_1_CLASS="ko"
	test ${AVG_1%%.*} -lt ${LOAD_MIN} && AVG_1_CLASS="ok"
	test ${AVG_5%%.*} -gt ${LOAD_MAX} && AVG_5_CLASS="ko"
	test ${AVG_5%%.*} -lt ${LOAD_MIN} && AVG_5_CLASS="ok"
	test ${AVG_15%%.*} -gt ${LOAD_MAX} && AVG_15_CLASS="ko"
	test ${AVG_15%%.*} -lt ${LOAD_MIN} && AVG_15_CLASS="ok"
	print_template "load" $1
}

# 
# Display RAM status
# Templates:
#  - templates/ram.sh 
# Input Config variables:
#  - MEMORY_LIMIT = % of minimum free RAM above which the "ok" class is used.
#  - SWAP_LIMIT = % of minimum free SWAP above which the "ok" class is used.
# Output Template variables:
#  - RAM_FREE_PERC = percentage of free RAM
#  - SWAP_FREE_PERC = percentage of free SWAP
#  - RAM_CLASS = class to use for RAM (ok if <= limit, ko if > limit)
#  - SWAP_CLASS = class to use for SWAP (ok if <= limit, ko if > limit)
#  - RAM_FREE_MB = free megabytes of ram (as real number)
#  - RAM_TOT_MB  = total megabytes of ram (as real number)
#  - RAM_FREE_GB = free gigabytes of ram (as real number)
#  - RAM_TOT_GB  = total gigabytes of ram (as real number)
#  - SWAP_FREE_MB = free megabytes of swap (as real number)
#  - SWAP_TOT_MB  = total megabytes of swap (as real number)
#  - SWAP_FREE_GB = free gigabytes of swap (as real number)
#  - SWAP_TOT_GB  = total gigabytes of swap (as real number)
function print_ram()
{
	parse_meminfo
	local RAM_FREE_PERC=$(( ${MEM_AVA} * 100 /${MEM_TOT} ))
	if [ ${RAM_FREE_PERC} -lt ${MEMORY_LIMIT} ]
	then
		RAM_CLASS="ko"
	else
		RAM_CLASS="ok"
	fi
	local SWAP_FREE_PERC=$(( ${SWAP_FRE} * 100 /${SWAP_TOT} ))
	if [ ${SWAP_FREE_PERC} -lt ${SWAP_LIMIT} ]
	then
		SWAP_CLASS="ko"
	else
		SWAP_CLASS="ok"
	fi
	RAM_FREE_MB=$(( MEM_AVA/1024 )).$(( MEM_AVA%1024/10 ))
	RAM_TOT_MB=$(( MEM_TOT/1024 )).$(( MEM_TOT%1024/10 ))
	RAM_FREE_GB=$(( MEM_AVA/1024/1024 )).$(( MEM_AVA/1024%1024/10 ))
	RAM_TOT_GB=$(( MEM_TOT/1024/1024 )).$(( MEM_TOT/1024%1024/10 ))
	SWAP_FREE_MB=$(( SWAP_FRE/1024 )).$(( SWAP_FRE%1024/10 ))
	SWAP_TOT_MB=$(( SWAP_TOT/1024 )).$(( SWAP_TOT%1024/10 ))
	SWAP_FREE_GB=$(( SWAP_FRE/1024/1024 )).$(( SWAP_FRE/1024%1024/10 ))
	SWAP_TOT_GB=$(( SWAP_TOT/1024/1024 )).$(( SWAP_TOT/1024%1024/10 ))

	print_template "ram" $1
}

# Main HTML output.
# This will be incorporated into the dashboard with an AJAX GET, so there is no need to output a fully formed HTML with header, body, etc.
# The following is the bare minimum needed for this output to be properly processed by the web server and the browser, including the needed CSS.
echo "Content-type: text/html"
echo ""
echo '<link rel="stylesheet" href="'${BASE_URL}'monitor.css?ver=1"/>'

# Detect how we are called (our script name) and decide which output configuration to generate
# based on the PAGES configuration variable
#
# The PAGES variable format is:
# PAGES=("page1" "page2" ...)
# the name must match the "page" GET parameter.
#
# Pages can be configured with the WIDGETS array:
# WIDGETS["page1"]="widget1:config_key widget2:config_key ..."
#
# Where widget is the name of the item to display, and config_key is used to specify specific configurations for the item
#
#
called_as=${0##*/}
selected_page=$1
if [ "$REQUEST_METHOD" = "GET" ]
then
	page_enc=$(echo "$QUERY_STRING" | sed -n 's/^.*page=\([^&]*\).*$/\1/p')
	selected_page=$(echo -e $(echo "$page_enc" | sed 's/+/ /g;s/%\(..\)/\\x\1/g;'))    # html decode
fi

if [ -n ${selected_page} ]
then
	for page in "${PAGES[@]}"
	do
		if [ "${page}" = "${selected_page}" ]
		then
			for widget in ${WIDGETS[$page]}
			do
				item=${widget%:*}
				config_key=${widget#*:}
				print_${item} ${config_key}
			done
		fi
	done
fi

