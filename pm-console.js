// This Script depends on jQuery 1.3.2
// main
function main(method){
    var auth = getAuth("Admin", "zabbix");
    var rpcid = auth.id + 1;
    var filter = new Object();
    var params = new Object();
        params.output = "extend";
        params.limit = 1;
        params.filter = filter;

    var descriptions = new Array();
        descriptions[0] = "Number of running processes heartbeat master";
        descriptions[1] = "Number of running processes heartbeat FIFO reader";
        descriptions[2] = "Number of running processes heartbeat write";
        descriptions[3] = "Number of running processes heartbeat read";
        descriptions[4] = "Number of running processes heartbeat attrd";
        descriptions[5] = "Number of running processes heartbeat ccm";
        descriptions[6] = "Number of running processes heartbeat cib";
        descriptions[7] = "Number of running processes heartbeat crmd";
        descriptions[8] = "Number of running processes heartbeat lrmd";
        descriptions[9] = "Number of running processes heartbeat stonithd";
        descriptions[9] = "Number of running processes heartbeat pengine";

    var lastvalues = new Array();
    var objResult = new Object();
    for (var i = 0; i < descriptions.length; i++) {
        filter.description = descriptions[i];
        filter.hostid = "10070"; //kayo01
        objResult = getZabbixData(rpcid, auth.result, method, params);
        lastvalues[i] = objResult.result[0].lastvalue;
        rpcid++;
    }
    
    drawGraph(rpcid, auth.result);
    rpcid++;
    
    var strTable = "";
    strTable += "<table>";
    strTable += "<tr><th>";
    strTable += "Description";
    strTable += "</th><th>";
    strTable += "Value";
    strTable += "</th></tr>";
    
    for (var i = 0; i < descriptions.length; i++) {
        strTable += "<tr><td>";
        strTable += descriptions[i];
        strTable += "</td><td>";
        strTable += lastvalues[i];
        strTable += "</td></tr>";
    }
    strTable += "</table><br>";
    document.getElementById("datatable").innerHTML = strTable;
}

//API Access Authentication
function getAuth(user, password) {
    var params = {"user":user, "password":password};
    var authRequest = new Object();
        authRequest.params = params;
        authRequest.auth = null;
        authRequest.jsonrpc = '2.0';
        authRequest.id = 0;
        authRequest.method = 'user.authenticate';
    var authJsonRequest = JSON.stringify(authRequest);
    var authResult = new Object();
    $.ajax({
        url: '/zabbix/api_jsonrpc.php',
        contentType: 'application/json-rpc',
        dataType: 'json',
        type: 'POST',
        processData: false,
        async: false, // 認証が終わらないと次の処理ができないので、ここは同期通信に。
        data: authJsonRequest,
        success: function(response){
            authResult = response;
        },
        error: function(){ alert("failed"); },
    });
    return(authResult); // 認証結果をObjectとして返して"auth.id", "auth.result"で取り出す。
}

// Access Zabbix API and Get Data
function getZabbixData(rpcid, authid, method, params) { // "params"はJSON形式の文字列リテラルかJSONに変換可能なオブジェクト
    var dataRequest = new Object();
        dataRequest.params = params;
        dataRequest.auth = authid;
        dataRequest.jsonrpc = '2.0';
        dataRequest.id = rpcid;
        dataRequest.method = method;
    var dataJsonRequest = JSON.stringify(dataRequest);
    var dataResult = new Object();
    $.ajax({
        type: 'POST',
        url: '/zabbix/api_jsonrpc.php',
        contentType: 'application/json-rpc',
        dataType: 'json',
        processData: false,
        async: false,
        data: dataJsonRequest,
        success: function(response){
            dataResult = response;
            //showResult(response);
        },
        error: function(response){ alert("failed"); },
    });
    return(dataResult);
}
