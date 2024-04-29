
echo "<div class='monitor_title'>Services status:</div>"
echo "<table>"
local step=0
local i=0
while [ ${i} -lt ${NUM_SERVICES} ]
do
	if [ ${step} -eq 0 ]
	then
		pre="<tr>"
		post=
		step=1
	else
		pre=
		post="</tr>"
		step=0
	fi
	echo ${pre}
	echo "<td><span>${SERVICE_NAMES[${i}]}</span></td>"
	echo "<td><span class='${SERVICE_CLASS[${i}]}'></span></td>"
	echo ${post}
	i=$(( i+1 ))
done
echo "</table>"

