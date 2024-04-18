
echo "<div class='monitor_title'>Load average:</div>"

echo "<table>"
echo "<tr>"
echo "<td><span>1 min: ${AVG_1}</span></td>"
echo "<td><span  class='${AVG_1_CLASS}'></span></td>"
echo "</tr>"
echo "<tr>"
echo "<td><span>5 min: ${AVG_5}</span></td>"
echo "<td><span  class='${AVG_5_CLASS}'></span></td>"
echo "</tr>"
echo "<tr>"
echo "<td><span>15 min: ${AVG_15}</span></td>"
echo "<td><span  class='${AVG_15_CLASS}'></span></td>"
echo "</tr>"
echo "</table>"

