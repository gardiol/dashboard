
echo "<div class='monitor_title'>${TITLE}</div>"

local MAX_COLUMNS=$(( COLUMNS-1 ))
echo "<table>"
N=0
while [ ${N} -lt ${PING_NUM} ]
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
	echo "<td><span>${PING_HOSTS[${N}]}</span></td>"
	echo "<td><span class='${PING_CLASS[${N}]}'></span></td>"
	echo ${post}
	N=$(( N+1 ))
done

echo "</table>"
