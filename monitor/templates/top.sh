
i=0
echo "<div class='monitor_title'>Top tasks</div>"
echo "<table>"
while [ ${i} -lt ${NUM_TASKS} ]
do
	echo "<tr>"
	echo "<td>"
	echo "<div>${TASKS_CMD[${i}]} - ${TASKS_CPU_PER[${i}]}%</div>"
	echo "<div class='monitor_extra ${TASKS_CLASS[${i}]}_color'>${TASKS_USER[${i}]}(${TASKS_PID[${i}]})</div>"
	echo "</td>"
	echo "<td><span class='${TASKS_CLASS[${i}]}'></span></td>"
	echo "</tr>"
	i=$(( i+1 ))
done
echo "</table>"
echo "</div>"

