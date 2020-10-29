#!/bin/bash
#Autor: Claudio Lazaro Silva Santos
#Objetivo: Coleta de dados informix para apresentacao de report-daily
#Dados:
#	BACKUP
#	DBSPACE
#	PAGINAS USADAS
#	ALERTAS


printf "Resolvendo daily report ...\n"

INFORMIXDIR=$INFORMIXDIR
INFORMIXSERVER=$INFORMIXSERVER
DBACCESS=$INFORMIXDIR/bin/dbaccess

ARCHOSTS=$1
AWK=`which awk`
WC=`which wc`
CUT=`which cut`
ECHO=`which echo`
CAT=`which cat`
RM=`which rm`
SORT=`which sort`
DATE=`which date`
MAILX=`which mailx`


INFO_DB="INFO_DB"


fc_main(){

    if [ -e $ARCHOSTS ]
        then
            printf "Arquivo de hosts encontrado. \n"
            
            sleep 2;

        if [  -s $ARCHOSTS ]
            then
                for x in $($CUT -d " " -f 1 $ARCHOSTS)
                    do get_backup $x;get_dbspace $x;get_pageused $x;get_phalert $x;
                    done
                	gen_html
                	send_mail
                	$RM -rf Report_Diario_$(date +"%d-%m-%Y_%H").html
                exit 0;
            else
                 printf "O Arquivo ${ARCHOSTS} nao contem dados. \n"

                exit 1;

                fi

        exit 0;
    fi


}

get_backup(){

printf "Coletando Informacoes do backup. \n"

$DBACCESS sysmaster@${1} &>> /dev/null <<+
database sysutils;
set isolation dirty read;
UNLOAD TO 'BACKUP_${1}'
SELECT 
first 1 '${1}' as Unidade, 
MIN(b.act_start) AS inicio, 
MAX(b.act_end) AS Fim,
CASE
	WHEN (MAX(b.act_end) < (TODAY - 1)) THEN "Critical"
	ELSE "No Attention"
END health, 
(MAX(b.act_end) - MIN(b.act_start)) AS Duracao FROM bar_object a, 
bar_action b, 
bar_instance c 
WHERE c.ins_oid = a.obj_oid 
AND c.ins_aid  = b.act_aid 
AND c.ins_level = 0 
AND a.obj_type != 'L' 
AND c.ins_first_log IN (SELECT UNIQUE ins_first_log FROM bar_instance) 
GROUP BY c.ins_first_log 
ORDER BY 2 desc;
+
printf "Processo de Backup Finalizado. \n"
    if [ -s BACKUP_${1} ]

        then 
            printf "Os dados do data base : ${1} foram importados com sucesso! \n"

        else
             printf "Os dados do data base : ${1} nao foram econtrados. \n"
            $ECHO "${1}|BACKUP|DADOS NAO RECUPERADOS|Critical|" >> INFO_DB
    fi
$CAT BACKUP_${1} >> BACKUP_COLLECT
$RM -rf BACKUP_${1}

}

get_dbspace(){

printf "Coletando Informacoes do dbspace. \n"

$DBACCESS sysmaster@${1} &>> /dev/null <<+
database sysmaster;
set isolation dirty read;
UNLOAD TO 'DBSPACE_${1}'
select 
'${1}' as Undiade,
a.dbsnum, 
a.name[1,20], 
trunc(sum(b.chksize)*2/1024/1024) Alocado_GB, 
trunc(sum(b.nfree)*2/1024/1024) Livre_Gb,
case 
	when trunc(sum(b.nfree)*2/1024/1024) <= 10 then "Critical"
	else "No Attention"
end health, 
trunc((sum(b.nfree)*2/1024)*100/(sum(b.chksize)*2/1024),2) Perc_livre 
from sysdbspaces a, syschunks b 
where b.dbsnum=a.dbsnum
and a.name not like "%temp%"
and a.name not like "%root%"
and a.name not like "%log%"
and a.name not like "%phy%"
and a.name not like "%dbs_p%" 
group by 2, 3 
having trunc(sum(b.nfree)*2/1024/1024) < 15
order by 2;
+
    if [ -s DBSPACE_${1} ]

        then 
            printf "Os dados do data base : ${1} foram importados com sucesso! \n"

        else
             printf "Os dados do data base : ${1} nao foram econtrados. \n"
            $ECHO "${1}|DBSPACE|DADOS NAO RECUPERADOS|No Action|" >> INFO_DB
    fi
$CAT DBSPACE_${1} >> DBSPACE_COLLECT
$RM -rf DBSPACE_${1}

}

get_pageused(){

printf "Coletando Informacoes de paginas usadas. \n"

$DBACCESS sysmaster@${1} &>> /dev/null <<+
batabase sysmaster;
set isolation dirty read;
UNLOAD TO 'PAGEUSED_${1}'
select  '${1}' as Undiade,
	{+  ORDERED  INDEX(x0 "systabs_pnix" ) INDEX(x1 "sysptnhdridx") } x0.dbsname ,
	x0.tabname ,
	x1.nptotal ,
	x1.npused ,
	case 
		when (x1.npused > 13421772 ) then "Critical"
		else "No Attention"
	end health,
	x1.npdata ,
	round(sum((x1.nptotal - x1.npdata ) ) ) pglivre,
	x1.pagesize
from 
    sysmaster:"informix".systabnames x0 ,sysmaster:"informix".sysptnhdr x1 
where (x0.partnum = x1.partnum )
and x1.npused > 11744028 
group by x0.dbsname ,
	x0.tabname ,
	x1.nptotal ,
	x1.npused ,
	x1.npdata ,
	x1.pagesize 
order by 4 desc;
+
    if [ -s PAGEUSED_${1} ]

        then 
            printf "Os dados do data base : ${1} foram importados com sucesso! \n"

        else
             printf "Os dados do data base : ${1} nao foram econtrados. \n"
            $ECHO "${1}|PAGINAS|DADOS NAO RECUPERADOS|No Action|" >> INFO_DB
    fi
$CAT PAGEUSED_${1} >> PAGEUSED_COLLECT
$RM -rf PAGEUSED_${1}

}

get_phalert(){

printf "Coletando Informacoes sobre alertas. \n"

$DBACCESS sysmaster@${1} &>> /dev/null <<+
database sysmaster;
set isolation dirty read;
UNLOAD TO 'ALERT_${1}'
select
'${1}' as Undiade,
alert_type,
alert_time,
SUBSTRING (alert_message FROM 1 FOR 70) 
from sysadmin:ph_alert
where alert_type <> "INFO"
and alert_time = TODAY 
order by id desc; 
+
    if [ -s ALERT_${1} ]

        then 
            printf "Os dados do data base : ${1} foram importados com sucesso! \n"

        else
             printf "Os dados do data base : ${1} nao foram econtrados. \n"
            $ECHO "${1}|ALERTAS|DADOS NAO RECUPERADOS|No Action|" >> INFO_DB
    fi
$CAT ALERT_${1} >> ALERT_COLLECT
$RM -rf ALERT_${1}

}

#Funcao que gera o report em html

gen_html(){
$ECHO "<!DOCTYPE html>"
$ECHO "<html>"
$ECHO "<style type='text/css'>
body { font-family: Consolas, monaco, monospace; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: 20px; }
h1 { font-family: Consolas; font-size: 12px; font-style: normal; font-variant: normal; font-weight: 700; line-height: 13.2px; }
h3 { font-family: Consolas, monaco, monospace; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 700; line-height: 15.4px; }
p { font-family: Consolas, monaco, monospace; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: 20px; }
blockquote { font-family: Consolas, monaco, monospace; font-size: 21px; font-style: normal; font-variant: normal; font-weight: 400; line-height: 30px; }
pre { font-family: Consolas, monaco, monospace; font-size: 13px; font-style: normal; font-variant: normal; font-weight: 400; line-height: 1; } 
.accordion {
  background-color: #eee;
  color: #444;
  cursor: pointer;
  padding: 18px;
  width: 100%;
  text-align: left;
  border: none;
  outline: none;
  transition: 0.4s;
}

/* Add a background color to the button if it is clicked on (add the .active class with JS), and when you move the mouse over it (hover) */
.active, .accordion:hover {
  background-color: #ccc;
}

/* Style the accordion panel. Note: hidden by default */
.panel {
  padding: 0 18px;
  background-color: white;
  display: none;
  overflow: hidden;
}

.content {
  padding: 0 18px;
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.2s ease-out;
  background-color: #f1f1f1;
}

.div {border: 1px solid red;display:table;}

table {
  border-collapse: collapse;
  border-spacing: 0;
  width: 70%;
  border: 1px solid #ddd;
}

th, td {
  text-align: left;
  padding: 8px;
}

tr:nth-child(even){background-color: #f2f2f2}

}

</style>"
$ECHO "<head>"
$ECHO "<meta charset="UTF-8">"
$ECHO "<title>Relatorio Tecnico - Infra-Estrutura</title>"
$ECHO "</head>"
$ECHO "<body>"
$ECHO "<table>"
$ECHO "<tr><th><a class="titulo">"Data da Criacao $(date +'%d de %B %Y %H:%M')"<a/></th></tr>"
$ECHO "<table>"
$ECHO "<h2>Relatorio Diario Informix</h2>"
$ECHO "<br>"
$ECHO "<br>"
$ECHO "<div>"
$ECHO '<br><b>Data dos Backups </b><br>'
$ECHO "<br>"
$ECHO "<table>"
$ECHO "<tr>"
$ECHO "  <th>Unidade</th>"
$ECHO "  <th>Inicio</th>"
$ECHO "  <th>Termino</th>"
$ECHO "  <th>health</th>"
$ECHO "  <th>Tempo</th>"
$ECHO "</tr>"
if [[ -e BACKUP_COLLECT ]];then
	$CAT BACKUP_COLLECT| $AWK 'BEGIN { FS="|"} function printRow(tag) {if ($4=="Critical") print"<tr style='background-color:#ffb3b3'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	$RM  -rf BACKUP_COLLECT
else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	$RM  -rf BACKUP_COLLECT	
fi
$ECHO "</table>"

$ECHO '<br><b>Uso do Dbspace</b><br>'
$ECHO '<p>É muito importante que os administradores de banco de dados Informix se mantenham informados sobre o espaço em cada um dbspace.</p>'

$ECHO "<table>"
$ECHO "<tr>"
$ECHO "  <th>Unidade</th>"
$ECHO "  <th>dbsnum</th>"
$ECHO "  <th>Name/Index</th>"
$ECHO "  <th>Alocado_gb</th>"
$ECHO "  <th>Livre_gb</th>"
$ECHO "  <th>health</th>"
$ECHO "  <th>Percent</th>"
$ECHO "</tr>"
if [[ -e DBSPACE_COLLECT ]];then
	$CAT DBSPACE_COLLECT| $SORT -t "|"  -n -k 5 | $AWK 'BEGIN { FS="|"} function printRow(tag) {if ($6=="Critical") print"<tr style='background-color:#ffb3b3'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	$RM -rf DBSPACE_COLLECT
else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	$RM -rf DBSPACE_COLLECT	
fi
$ECHO "</table>"

$ECHO '<br><b>Top 10 Table com limite de paginas por fragmento </b><br>'

$ECHO '<p>O informix nao suporta mais de 16777215 paginas por fragmento, quando isso ocorre e necessario atuacao imediata, como particionamento da tabela ou alocar em um dbspace de paginas maiores</p>'

$ECHO "<table>"
$ECHO "<tr>"
$ECHO "  <th>Unidade</th>"
$ECHO "  <th>database</th>"
$ECHO "  <th>tabela</th>"
$ECHO "  <th>pgalocada</th>"
$ECHO "  <th>pgusadas</th>"
$ECHO "  <th>health</th>"
$ECHO "  <th>dataporpg</th>"
$ECHO "  <th>totalpglivre</th>"
$ECHO "  <th>sizepg</th>"
$ECHO "</tr>"
if [[ -e PAGEUSED_COLLECT ]];then
	$CAT PAGEUSED_COLLECT | $SORT -t "|" -nr -k 4 | $AWK 'BEGIN { FS="|"} function printRow(tag) {if (int($4) > int(13421772)) print"<tr style='background-color:#ffb3b3'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	$RM -rf PAGEUSED_COLLECT
else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	$RM -rf PAGEUSED_COLLECT
	
fi
$ECHO "</table>"

$ECHO '<br><b>Scheduler informix Menssagens</b><br>'
$ECHO '<p>Check de menssagens ph_alert</p>'

if [[ -s ALERT_COLLECT ]];then

$ECHO "<table>"
$ECHO "<tr>"
$ECHO "  <th>Unidade</th>"
$ECHO "  <th>alert_type</th>"
$ECHO "  <th>alert_time</th>"
$ECHO "  <th>tk_name</th>"
$ECHO "  <th>alert_message</th>"
$ECHO "</tr>"
if [[ -e ALERT_COLLECT ]];then
	$CAT ALERT_COLLECT | $AWK 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	$RM -rf ALERT_COLLECT
else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	$RM -rf ALERT_COLLECT

fi

else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS, ISSO PODE OCORER QUANDO NAO EXISTEM ALERTAS </b><br>"

fi
$ECHO "</table>"

$ECHO '<br><b>LOG DE RETORNO DE DADOS</b><br>'
$ECHO '<p>Resumo das coletas que nao apresentaram dados.</p>'

$ECHO "<table>"
$ECHO "<tr>"
$ECHO "  <th>Unidade</th>"
$ECHO "  <th>Tipo</th>"
$ECHO "  <th>Info</th>"
$ECHO "  <th>Action</th>"
$ECHO "</tr>"
if [[ -e INFO_DB ]];then
	$CAT INFO_DB| $AWK 'BEGIN { FS="|"} function printRow(tag) {if ($4=="Critical") print"<tr style='background-color:#ffb3b3'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	$RM -rf INFO_DB
else
	$ECHO "<br><b>DADOS NAO ENCONTRADOS</b><br>"	
fi
$ECHO "</div>"
$ECHO "</table>"
$ECHO "</body>"
$ECHO "</html>"
}>Report_Diario_$(date +"%d-%m-%Y_%H").html

send_mail(){
printf "Enviando report por email ...\n"
$MAILX -s "$($ECHO -e "Daily_Informix_$(date +"%d-%m-%Y_%H")\nContent-Type: text/html\ncharset="iso-8859-1"")" -S smtp='smsmtp.youdomain.com.br' -S smtp-auth=login -S smtp-auth-user=mx -S smtp-auth-password=mx@pwd -r informix@domain.com.br clazar@domain.com.br < Report_Diario_$(date +"%d-%m-%Y_%H").html
}

#MAIN FUNCITION CALL ALL OTHER FUNCTIONS
fc_main
