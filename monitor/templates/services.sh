
echo "<div class='monitor_title'>${TITLE}</div>"
echo "<table>"
local col=0
local i=0
local MAX_COLUMNS=$(( COLUMNS-1 ))
while [ ${i} -lt ${NUM_SERVICES} ]
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
	echo "<td><span>${SERVICE_NAMES[${i}]}</span></td>"
	echo "<td><span class='${SERVICE_CLASS[${i}]}'></span></td>"
	echo ${post}
	i=$(( i+1 ))
done
echo "</table>"

