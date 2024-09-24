
echo "<div class='monitor_title'>${TITLE}</div>"

local sep1="</tr><tr>"
local sep2="</tr><tr>"
if [ ${COLUMNS} -gt 1 ]
then
	sep1=""
	sep2=""
fi

echo "<table>"
echo "<tr>"
echo "<td><span>1 min: ${AVG_1}</span></td>"
echo "<td><span  class='${AVG_1_CLASS}'></span></td>"
echo $sep1
echo "<td><span>5 min: ${AVG_5}</span></td>"
echo "<td><span  class='${AVG_5_CLASS}'></span></td>"
echo $sep2
echo "<td><span>15 min: ${AVG_15}</span></td>"
echo "<td><span  class='${AVG_15_CLASS}'></span></td>"
echo "</tr>"
echo "</table>"

