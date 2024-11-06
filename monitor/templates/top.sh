
i=0
echo "<div class='monitor_title'>${TITLE}</div>"

local MAX_COLUMNS=$(( COLUMNS-1 ))
col=0

echo "<table>"
while [ ${i} -lt ${NUM_TASKS} ]
do
	if [ ${COLUMNS} -gt 1 ]
	then
		if [ ${col} -eq 0 ]
		then
			pre="<tr>"
			post=
			col=1
		elif [ ${col} -ge ${MAX_COLUMNS} ]
		then
			pre=
			post="</tr>"
			col=0
		else
			pre=
			post=
			col=$(( col+1 ))
		fi
	else
		pre="<tr>"
		post="</tr>"
	fi
	echo ${pre}
	echo "<td>"
	echo "<div>${TASKS_CMD[${i}]} - ${TASKS_CPU_PER[${i}]}%</div>"
	echo "<div class='monitor_extra ${TASKS_CLASS[${i}]}_color'>${TASKS_USER[${i}]}(${TASKS_PID[${i}]})</div>"
	echo "</td>"
	echo "<td><span class='${TASKS_CLASS[${i}]}'></span></td>"
	echo ${post}

	i=$(( i+1 ))
done
echo "</table>"
echo "</div>"

