
i=0
echo "<div class='monitor_title'>Top tasks</div>"
echo "<table>"
while [ ${i} -lt ${NUM_TASKS} ]
do
	echo "<tr>"
	echo "<td><span>${TASKS_CMD[${i}]} - ${TASKS_CPU_PER[${i}]}%</span></td>"
	echo "<td><span class='${TASKS_CLASS[${i}]}'></span></td>"
	echo "</tr>"
	i=$(( i+1 ))
done
echo "</table>"
echo "</div>"

