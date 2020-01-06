#ReportHtmlGenerator(){
#Autor : Claudio Lazaro Santos
#Funcao: Gerar Report Em HTML5
#https://docs.deistercloud.com/Databases.30/IBM%20Informix.2/Monitoring.10.xml?embedded=true
{
LOGBANCOS="/tmp/1234_$(whoami)_pode_deletar_1234_1_BANCOS.log"
UNLOAD="/tmp/$(whoami)_deletar.unl"

echo "<!DOCTYPE html>"
echo "<html>"
echo "<style type='text/css'>
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
echo "<head>"
echo "<meta charset="UTF-8">"
echo "<title>Relatorio Tecnico - Infra-Estrutura</title>"
echo "</head>"
echo "<body>"
echo "<table>"
echo "<tr><th><a class="titulo">"Data da Criacao $(date +'%d de %B %Y %H:%M')"<a/></th></tr>"
echo "<table>"
echo "<h2>Relatorio de suporte a troubleshooting ambientes Informix.</h2>"
echo "<br>"
echo "<br>"
# =============================================
#     INFORMACOES SISTEMA OPERACIONAL
# =============================================
echo "<h2>Informacoes Sistema Operacional</h2>"
echo "<div>"

echo "<br><b>Versao SO </b><br>"
uname -a |awk '{print $0"<br>"}'


echo '<br><b>Memoria</b><br>'
free -m |awk '{print $0"<br>"}'

echo '<br><b>Memoria Alocada Para o Banco</b><br>'
MEMORIA=$(onstat -g seg|awk '/Total/ {print $4}')
#MEMORIA=1000000000
echo "Quantidade da Memoria Alocada pelo Informix (Gbytes) = "$(($MEMORIA /1024^3))

echo "<pre>"

echo "<br><b>Processadores</b><br>"
# echo "Sockets:"
printf "%s: %s\n" "Sockets:" "$(grep -c ^processor /proc/cpuinfo |awk '{print $0}')"
cat /proc/cpuinfo|grep -m 1 'vendor_id'|awk '{print $0}'
cat /proc/cpuinfo|grep -m 1 'model name'|awk '{print $0}'
cat /proc/cpuinfo|grep -m 1 'cpu MHz'|awk '{print $0}'
cat /proc/cpuinfo|grep -m 1 'cache size'|awk '{print $0}'

echo '<br><b>Processos top 20 </b><br>'
#system.cpu.load[,avg5]
#zabbix_get -s localhost -k  net.dns[,grupoamil.com.br]
#zabbix_get -s localhost -k  vfs.dev.writ[,,avg5]
top -b -n 1|head -n 5|awk '{print $0"<br>"}'
echo "<br>"
ps -eo user,comm,pid,ppid,pcpu,%mem --sort -pcpu|head -20|awk 'int($5) > int(90) {print "<span style=\"font-size:28px;color:red;margin-right:10px;\">&#9888;</span><span style=\"color:red;font-weight:bold;\">"$0"</span><br>";next};{print $0"<br>"}'


echo '<br><b>Limites IPCS</b></br>'
ipcs -l |awk '{print $0"<br>"}'
ipcs -a |awk '{print $0"<br>"}'

echo '<br><b>Performace VMSTAT</b></br>'
vmstat  |awk '{print $0"<br>"}'

#echo '<br><b>Performace Gravacao de Blocos</b><br>'
#dd if=/dev/zero of=/tmp/laptop.bin bs=2k count=1000 oflag=direct|awk '{print $0"<br>"}';rm -rf /tmp/laptop.bin
#dd if=/dev/zero of=/tmp/laptop.bin bs=4k count=1000 oflag=direct|awk '{print $0"<br>"}';rm -rf /tmp/laptop.bin
#dd if=/dev/zero of=/tmp/laptop.bin bs=8k count=1000 oflag=direct|awk '{print $0"<br>"}';rm -rf /tmp/laptop.bin
#dd if=/dev/zero of=/tmp/laptop.bin bs=16k count=1000 oflag=direct|awk '{print $0"<br>"}';rm -rf /tmp/laptop.bin

echo '<br><b>Discos</b><br>'
#Se a ocupacao dos disco for maior que 70% a linha fiacara em vermelho
df -hPT |awk 'int(substr($6,1,length($6)-1)) > int(70) {print "<span style=\"color:red\">"$0"</span><br>";next};{print $0"<br>"}'

echo '<br><b>netstat -s </b><br>'
netstat -s |awk '{print $0"<br>"}'

echo '<br><b>Verificando Servidores de DNS</b><br>'
DNST="/tmp/dnstemp"
cat /etc/resolv.conf |awk '/[0-9][0-9][0-9]/ {print system("ping -c 2 "$2)}' &>> $DNST
if [[ -e $DNST ]];then
	awk '{print $0 "<br>"}' $DNST
	rm -rf $DNST	
else 
 	echo "Sem Dados Para Consulta, verifique o arquivo resolv.conf <br>"
fi 

echo '<br><b>Resumo das interfaces</b><br>'
ip addr |awk '{print $0 "<br>"}'
echo "</div>"

echo "<h2>Informacoes do Banco de Dados - Basic</h2>"
echo "<div>"
echo '<br><b>Ferramentas de monitoramento</b><br>'
echo '<p>O Informix fornece duas ferramentas principais para monitorar o desempenho do sistema e do banco de dados:</p>'

echo '<p>O onstat utilitário.</p>' 
echo '<p>Tem Inúmeras SMI tabelas da interface de monitoramento do sistema ( ) no banco de dados sysmaster, criadas automaticamente no momento da primeira inicialização do IDS.</p>'
echo '<p>O utilitário onstat e as SMI tabelas monitoram o IDSdesempenho examinando IDSas atividades de memória compartilhada, mas há uma diferença na maneira de apresentar essas estatísticas. O utilitário onstat sempre apresenta estatísticas de maneira fixa, enquanto o uso de SMI tabelas permite reorganizar essas estatísticas em um formato mais significativo e legível.</p>'

echo '<p>Uma coisa que precisamos prestar atenção é que as estatísticas coletadas pelo onstat ou nas SMItabelas são cumulativas a partir do momento da reinicialização ou IDS inicialização do sistema .</p>' 
echo '<p>Portanto, precisamos ter muito cuidado com essas estatísticas e sempre levar em consideração IDS o tempo de execução. Por exemplo, 100.000 bufwaits para um servidor em execução há mais de um mês é muito diferente dos 100.000 bufwaits em um único dia. Para obter estatísticas atuais, precisamos onstat -z zerar os valores antigos.</p>'

echo '<p>O Informix também fornece uma ferramenta de monitoramento gráfico - onperf. O Onperf coleta estatísticas de desempenho do servidor IDS e as plota em métricas. Também pode salvar essas estatísticas em um arquivo de texto para análise posterior. Consulte o Guia de Desempenho do Informix Dynamic Server para obter mais detalhes sobre o utilitário onperf.</p>'

echo '<p>As atividades do IDS podem ser classificadas em três categorias:</p>'

echo '<p>Atividades da instância</p>'
echo '<p>Atividades de banco de dados</p>'
echo '<p>Atividades da sessão</p>'
echo '<p>Usando as ferramentas discutidas acima, podemos monitorar efetivamente todas essas atividades.</p>'

echo '<br><b>Atividade da instância de monitoramento</b><br>'

echo '<p>Uma IDSinstância refere-se à Informix memória compartilhada, processadores Informix, bancos de dados Informix e dispositivos físicos alocados ao Informix. A seguir, estão algumas das atividades de instância mais importantes que precisamos monitorar.</p>'

echo "<div>"
echo '<p>O onstat -p comando que captura o modo operacional atual do IDS da seguinte maneira:</p>'
echo '<br>'
onstat -p |awk '{print $0"<br>"}'


echo '<br><b>Atividade da instância checkpoint</b><br>'
echo '<p>O checkpoint é o processo de sincronização de páginas em disco com páginas no buffer pool de memória compartilhada. Durante os pontos de verificação, IDS impede que os threads do usuário entrem na sessão crítica e bloqueie todas as atividades da transação. Portanto, se a duração do ponto de verificação for longa, os usuários poderão enfrentar uma interrupção do sistema. Isso é especialmente verdadeiro em OLTP ambientes onde existem milhares de transações e o tempo de resposta é mais crítico.</p>'
echo '<br>'
onstat -g ckp |awk '{print $0"<br>"}'


echo '<br><b>Utilizacao de Buffer Poll</b><br>'
onstat -P | egrep "page size|Percentages|^Data|^Btree|^Other" |awk '{print $0"<br>"}'


echo '<br><b>Uso do Dbspace</b><br>'
echo '<p>É muito importante que os administradores de banco de dados Informix se mantenham informados sobre o espaço em cada um dbspace. Se um dos dbspaces estiver faltando ou ficar sem espaço, ele IDS sofrerá. Todos os tipos de problemas podem ocorrer: não podemos importar nenhum banco de dados, não podemos criar tabelas e índices, não podemos sequer inserir e atualizar as tabelas e índices. Isso é muito crítico para bancos de dados de produção.</p>'

dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select 
b.name,
a.dbsnum,
a.pagesize, 
format_units(sum(chksize)*a.pagesize) sizeUsed,
format_units(sum(nfree)*a.pagesize) sizeFree,
trunc((sum(nfree)*100)/(sum(chksize)))||"%" Percent
from 
sysmaster:syschunks a, 
sysmaster:sysdbspaces b
where a.dbsnum=b.dbsnum
group by b.name,a.pagesize,a.dbsnum
order by a.dbsnum
and b.name not like '%temp%';
+
echo "<table>"
echo "<tr>"
echo "  <th>Name/Index</th>"
echo "  <th>dbsnum</th>"
echo "  <th>Page Size</th>"
echo "  <th>sizeUsed</th>"
echo "  <th>sizeFree</th>"
echo "  <th>Percent</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD| awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"	
fi
echo "</table>"

echo '<br><b>Níveis do índice</b><br>'
echo '<p>O número de níveis de índice também pode afetar adversamente o desempenho. Quanto mais níveis de índice, mais probes o IDS precisa obter para indexar nós de folhas. Além disso, se um nó folha for dividido ou mesclado, pode levar mais tempo para que todo o índice se ajuste a essa alteração. Por exemplo, se um índice tiver apenas dois níveis, apenas dois níveis precisarão ser ajustados, mas se tiver quatro níveis, todos os quatro níveis precisarão ser ajustados de acordo. O tempo usado para esse ajuste é, obviamente, muito mais longo. Isso é especialmente verdade em um ambiente OLTP em que há inserções, exclusões e atualizações constantes que farão com que os índices sejam constantemente divididos ou mesclados.</p>'

echo '<p>Se qualquer índice tiver mais de 4 níveis, considere descartá-lo e recriá-lo para consolidar seus níveis para obter melhor desempenho</p>'

dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
SELECT top 20 idxname[1,40], levels 
    FROM sysindexes 
    WHERE levels > 2	
ORDER BY 2 desc;
+
echo "<table>"
echo "<tr>"
echo "  <th>Name/Index</th>"
echo "  <th>levels</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {if (int($2) > int(3)) print"<tr bgcolor='#FF0000'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"

echo '<br><b>Top 20 maiores tabelas </b><br>'
echo '<p>Essas tabelas sao as top 20 maiores do banco de dados, deve ser acompanhadas e verificar a  possibilidade de particionamento</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select first 20 a.tabname, 
sum(b.nrows) nrow, 
b.pagesize, 
format_units(sum(trunc((nptotal*b.pagesize)))::CHAR(12)) size,
sum(trunc((nptotal*b.pagesize))) nptotal 
from sysmaster:systabnames a, sysmaster:sysptnhdr b 
where a.partnum = b.partnum 
and tabname not like "sys%" 
group by 1,3 order by 5 desc;
+
echo "<table>"
echo "<tr>"
echo "  <th>tabname</th>"
echo "  <th>nrow</th>"
echo "  <th>pagesize</th>"
echo "  <th>size</th>"
echo "  <th>nptotal</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"



echo '<br><b>Top 10 Table com limite de paginas por fragmento </b><br>'

echo '<p>O informix nao suporta mais de 16777215 paginas por fragmento, quando isso ocorre e necessario atuacao imediata, como particionamento da tabela ou alocar em um dbspace de paginas maiores</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select  first 10 {+  ORDERED  INDEX(x0 "systabs_pnix" ) INDEX(x1 "sysptnhdridx") } x0.dbsname ,
	x0.tabname ,
	x1.nptotal ,
	x1.npused ,
	x1.npdata ,
	round(sum((x1.nptotal - x1.npdata ) ) ) pglivre,
	x1.pagesize 
from 
    sysmaster:"informix".systabnames x0 ,sysmaster:"informix".sysptnhdr x1 
where (x0.partnum = x1.partnum ) 
group by x0.dbsname ,
	x0.tabname ,
	x1.nptotal ,
	x1.npused ,
	x1.npdata ,
	x1.pagesize 
    order by 3 desc;   
+
echo "<table>"
echo "<tr>"
echo "  <th>database</th>"
echo "  <th>tabela</th>"
echo "  <th>totalpgalocada</th>"
echo "  <th>pgusadas</th>"
echo "  <th>dataporpg</th>"
echo "  <th>totalpglivre</th>"
echo "  <th>sizepg</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {if (int($4) > int(13421772)) print"<tr style='background-color:red'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"



echo '<br><b>Sessoes e tempo em CPU </b><br>'
echo '<p>Verifique as sessoes em execucao</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
SELECT FIRST 20 s.sid, s.username, s.uid, s.pid, s.hostname, t.tid,t.name, t.statedesc, t.statedetail,t.cpu_time
FROM sysmaster:syssessions s, sysmaster:systcblst t, sysmaster:sysrstcb r, sysmaster:syssqlstat q
WHERE t.tid = r.tid AND s.sid = r.sid AND s.sid = q.sqs_sessionid
ORDER BY 10 DESC;
+
echo "<table>"
echo "<tr>"
echo "  <th>sid</th>"
echo "  <th>username</th>"
echo "  <th>uid</th>"
echo "  <th>hostname</th>"
echo "  <th>tid</th>"
echo "  <th>name</th>"
echo "  <th>statedesc</th>"
echo "  <th>statedetail</th>"
echo "  <th>cpu_time</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"

echo '<br><b>Schedules informix</b><br>'
echo '<p>E inportante observar quais tasks podem estar impactando</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select tk_id, tk_name, tk_dbs,SUBSTRING (tk_description FROM 1 FOR 70),tk_frequency,tk_enable from sysadmin:ph_task where tk_enable='t';
+
echo "<table>"
echo "<tr>"
echo "  <th>tk_id</th>"
echo "  <th>tk_name</th>"
echo "  <th>tk_dbs</th>"
echo "  <th>tk_description</th>"
echo "  <th>tk_frequency</th>"
echo "  <th>tk_next_execution</th>"
echo "  <th>tk_enable</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"

echo '<br><b>Scheduler informix Menssagens</b><br>'
echo '<p>Check de menssagens ph_alert</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select first 20 alert_type,alert_time,SUBSTRING (alert_message FROM 1 FOR 70) from sysadmin:ph_alert order by id desc
+
echo "<table>"
echo "<tr>"
echo "  <th>alert_type</th>"
echo "  <th>tk_name</th>"
echo "  <th>alert_time</th>"
echo "  <th>alert_message</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"

echo '<br><b>Buffer Turnovers por hora</b><br>'
echo '<p>O ideal e que o BTR seja feito 7x por hora, caso o campo BTR esteja muito alto reveja as configuracoes de buffer poll</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select
	bufsize,
        pagreads,
        bufwrites,
        nbuffs,
        ((( pagreads + bufwrites ) /nbuffs ) / ( select (ROUND ((( sh_curtime - sh_pfclrtime)/60)/60) )  from sysshmvals ) ) BTR
from sysbufpool;
+
echo "<table>"
echo "<tr>"
echo "  <th>bufsize</th>"
echo "  <th>pagreads</th>"
echo "  <th>bufwrites</th>"
echo "  <th>nbuffs</th>"
echo "  <th>BTR</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {if (int($4) > int(7)) print"<tr style='background-color:red'>";else print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"


echo '<br><b>Parametros do onconfig carregados  em memoria</b><br>'
echo '<p>Onconfig</p>'
dbaccess sysmaster &>> /dev/null <<+
set isolation dirty read;
UNLOAD TO '$UNLOAD'
select 	cf_name parameter, 
	cf_effective effective_value
from 	sysconfig
+
echo "<table>"
echo "<tr>"
echo "  <th>parameter</th>"
echo "  <th>effective_value</th>"
echo "</tr>"
if [[ -e "$UNLOAD" ]];then
	cat $UNLOAD | awk 'BEGIN { FS="|"} function printRow(tag) {print "<tr>";for(i=1; i<=NF; i++) print "<"tag">"$i"</"tag">";print "</tr>"} printRow("td")'
	rm -rf $UNLOAD
else
	echo "<br><b>DADOS NAO ENCONTRADOS</b><br>"
	
fi
echo "</table>"

	
echo "</div>"

echo "</pre>"
echo "<br>"
echo "<br>"
echo "<br>"
echo "<script>"
echo "var coll = document.getElementsByClassName('collapsible');"
echo "var i;"
echo "for (i = 0; i < coll.length; i++) {"
echo "  coll[i].addEventListener('click', function() {"
echo "    this.classList.toggle('active');"
echo "    var content = this.nextElementSibling;"
echo "    if (content.style.maxHeight){"
echo "      content.style.maxHeight = null;"
echo "    } else {"
echo "      content.style.maxHeight = content.scrollHeight + 'px';"
echo "    } "
echo "  });"
echo "}"
echo "</script>"
echo "</body>"
echo "</html>"
#Final do Arquivo
#}>ReportTecnico.html
}>ReportTecnico_$(date +"%d-%m-%Y_%H:%M").html
