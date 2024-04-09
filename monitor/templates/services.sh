
echo '<div>'

local step=0
local i=0
while [ ${i} -lt ${NUM_SERVICES} ]
do
	if [ ${step} -eq 0 ]
	then
		pre="<div>"
		post=
		step=1
	else
		pre=
		post="</div>"
		step=0
	fi
	echo "${pre}<span class='${SERVICE_CLASS[${i}]}'>${SERVICE_NAMES[${i}]}</span><span class='normal'>(${SERVICE_PID[${i}]})</span>${post}"
	i=$(( i+1 ))
done

echo '</div>'
