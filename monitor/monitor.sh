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
	export MP_PER=${data[4]}
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

function print_connectivity()
{
	for isp in ${UPLINKS}
	do
		local name=${isp%%:*}
		local gw_dest=${isp#*:}
		local gw=${gw_dest%%:*}
		local dest=${gw_dest##*:}
		connectivity_test ${gw} ${dest}
		if [ $GATEWAY_TEST -eq 0 ]
		then
			c1="ok"
			v1="Active";
		else
			c1="ko"
			v1="Down";
		fi
		if [ $DESTINATION_TEST -eq 0 ]
		then
			c2="ok"
			v2="Online";
		else
			c2="ko"
			v2="Offline";
		fi
		echo "<div><span class='normal'>${name}: </span><span class='${c1}'>${v1}</span> / <span class='${c2}'>${v2}</div>"
	
		echo "</div>"
	done
}

function print_pings()
{
	echo "<div><div class=''>Devices:</div>"
	for p in ${PINGS}
	do
		name=${p%:*}
		destination=${p#*:}
		echo "<div>"
		ping_test ${destination} 1
		if [ ${PING_OK} -eq 0 ]
		then
			class="ok"
			value="-up-";
		else
			class="ko"
			value="down";
		fi
		echo "<div><span class='normal'>${name}: </span><span class='${class}'>${value}</span></div>"
		echo "</div>"
	done
}

function print_mounts()
{
	echo '<div><div>Mounts:</div>'
	for mp in ${MOUNTPOINTS}
	do
		name=${mp%%:*}
		point=${mp##*:}
		parse_mountpoint "${point}"
		if [ ${MP_OK} -eq 0 ]
		then
			if [ ${MP_PER%%%} -lt ${FILESYSTEM_LIMIT} ]
			then
				class="ok"
			else
				class="ko"
			fi
		else
			class="ko"
		fi
		echo "<div class='${class}'>${name}: ${MP_PER}</div>"
	done
	echo '</div>'
}

function print_services()
{
	echo '<div>'
	local step=0
	for service in ${SERVICES_PIDS}
	do
		name=${service%%:*}
		pid_file=${service##*:}
		PID_RUN=0
		if [ -e ${pid_file} ]
		then
			parse_pidstatus $(cat ${pid_file})
		fi
		if [ ${PID_RUN} -eq 0 ]
		then
			class="ok"
		else
			class="ko"
		fi
		if [ ${step} -eq 0 ]
		then
			step=1
			echo "<div><span class='${class}'>${name}</span>"
		else
			step=0
			echo "<span class='${class}'>${name}</span></div>"
		fi
	done
	echo '</div>'
}

function print_load()
{
	parse_loadavg
	local class_1m="normal"
	local class_5m="normal"
	local class_15m="normal"
	test ${AVG_1%%.*} -gt ${LOAD_MAX} && class_1m="ko"
	test ${AVG_1%%.*} -lt ${LOAD_MIN} && class_1m="ok"
	test ${AVG_5%%.*} -gt ${LOAD_MAX} && class_5m="ko"
	test ${AVG_5%%.*} -lt ${LOAD_MIN} && class_5m="ok"
	test ${AVG_15%%.*} -gt ${LOAD_MAX} && class_15m="ko"
	test ${AVG_15%%.*} -lt ${LOAD_MIN} && class_15m="ok"

	echo '<div><div>Load average: </div>'
	echo '<div><span class="'${class_1m}'">'${AVG_1}'(1min)</span></div>'
	echo '<div><span class="'${class_5m}'">'${AVG_5}'(5min)</span></div>'
	echo '<div><span class="'${class_15m}'">'${AVG_15}'(15min)</span></div>'
}

function print_ram()
{
	parse_meminfo
	echo '<div><div>RAM memory:</div>'
	let mem_per=$(( ${MEM_AVA} * 100 /${MEM_TOT} ))
	if [ ${mem_per} -gt ${MEMORY_LIMIT} ]
	then
		class="ok"
	else
		class="ko"
	fi
	echo '<div class="'${class}'"><span>'$(( MEM_AVA/1024/1024 )).$(( MEM_AVA/1024%1024/10 ))/$(( MEM_TOT/1024/1024 )).$(( MEM_TOT/1024%1024/10 ))'Gb</span></div>'
	echo '<div class="'${class}'"><span>'${mem_per}'% free</span></div>' 
	echo '</div>'
}

# Main HTML output.
# This will be incorporated into the dashboard with an AJAX GET, so there is no need to output a fully formed HTML with header, body, etc.
# The following is the bare minimum needed for this output to be properly processed by the web server and the browser, including the needed CSS.
# For semplicity, this script uses the same site.css used by the dashboard, so all you need is to put your CSS in there.
echo "Content-type: text/html"
echo ""
echo '<link rel="stylesheet" href="'${BASE_UR}'site.css?ver=8"/>'

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

