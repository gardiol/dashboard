#!/bin/bash

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
	local ping_out=$(ping -n -q -c ${npings} -W 1 ${dest} 2> /dev/null)
	local tmp=${ping_out##*tt min/avg/max/mdev =}
	tmp=${tmp%[[:blank:]]ms*}
	tmp=(${tmp//\// })
	export PING_OK=$?
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
# Input:
# - 1: template name
#
function print_template()
{
	local TEMPLATE=$1
	echo "<div class='monitor_box'>"
	source "templates/${TEMPLATE}.sh"
	echo "</div>"
}

# 
# Display connectivity status
# Templates:
#  - templates/connectivity.sh 
# Inout Config variables:
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
	print_template "connectivity"
}

# 
# Display ping status
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
	for p in ${PINGS}
	do
		PING_HOSTS[${PING_NUM}]=${p%:*}
		ping_test ${p#*:}
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
	print_template "ping"
}

# 
# Display mountpoints and filesystems data
# Templates:
#  - templates/mounts.sh
# Inout Config variables:
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

	for mp in ${MOUNTPOINTS}
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
	print_template "mounts"
}

# 
# Display services/processes status
# Templates:
#  - templates/services.sh
# Inout Config variables:
#  - SERVICES_PIDS = list of services, format: name:pidfile name:pidfile ...
# Output Template variables:
#  - NUM_SERVICES   = number of services (size of arrays)
#  - SERVICE_NAMES  = array of service names
#  - SERVICE_CLASS  = class for service (ok if running, ko if not running)
#  - SERVICE_STATUS = 0(service is running) 1(service not running)
#  - SERVICE_PID    = PID of servicd
#
function print_services()
{
	local NUM_SERVICES=0
	local SERVICE_NAMES=()
	local SERVICE_CLASS=()
	local SERVICE_STATUS=()
	local SERVICE_PID=()
	for service in ${SERVICES_PIDS}
	do
		name=${service%%:*}
		pid_file=${service##*:}
		SERVICE_NAMES[${NUM_SERVICES}]="${name}"
		PID_RUN=1
		if [ -e ${pid_file} ]
		then
			SERVICE_PID[${NUM_SERVICES}]=$(<${pid_file})
			parse_pidstatus ${SERVICE_PID[${NUM_SERVICES}]}
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
	print_template "services"
}


# 
# Display system Load averages
# Templates:
#  - templates/load.sh
# Inout Config variables:
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
	print_template "load"
}

# 
# Display RAM status
# Templates:
#  - templates/ram.sh 
# Inout Config variables:
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

	print_template "ram"
}

# Main HTML output.
# This will be incorporated into the dashboard with an AJAX GET, so there is no need to output a fully formed HTML with header, body, etc.
# The following is the bare minimum needed for this output to be properly processed by the web server and the browser, including the needed CSS.
echo "Content-type: text/html"
echo ""
echo '<link rel="stylesheet" href="'${BASE_UR}'monitor.css?ver=8"/>'

# Detect how we are called (our script name) and decide which output configuration to generate
# based on the PAGES configuration variable
called_as=${0##*/}
for p in ${PAGES}
do
	page=${p%%:*}
	what=${p#*:}
	if [ "${page}" = "${called_as}" ]
	then
		last_what=""
		while [ "${what}" != "${last_what}" ]
		do
			item=${what%%:*}
			print_${item}
			last_what=${what}
			what=${what#*:}
		done
	fi
done

