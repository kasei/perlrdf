$(document).ready(function() {
	var editor = CodeMirror.fromTextArea('query', {
		height: "250px",
		parserfile: "parsesparql.js",
		stylesheet: "css/sparqlcolors.css",
		path: "/js/"
	});
});

//$(document).ready(function() {
//	$('#queryform').submit(function(e){
//		// Fallback for browser that don't support the history API
//		if (!('replaceState' in window.history)) {
//			alert('replaceState not available');
//			return true;
//		}
//		
//		// Ensure middle, control and command clicks act normally
//		if (e.which == 2 || e.metaKey || e.ctrlKey){
//			alert('meta key preventing replaceState');
//			return true;
//		}
//		
//		var url	= '?query=' + escape(editor.getCode());
//		alert(url);
//		$.get(url, function(results) {
//			window.history.pushState(null, "SPARQL Query Results", url);
//			alert(results.results.bindings[0]);
// 			$('#results').empty();
// 			if(results['results']['bindings']){
// 				for (var i in results['results']['bindings']) {
// 					var w		= results['results']['bindings'][i];
// 					var desc	= w['Description']['value'];
// 					var triples	= w['Number_of_Triples']['value'];
// 					var agency	= w['Agency']['value'];
// 					var title	= w['Title']['value'];
// 	
// 					var ok	= true;
// 					if (keyword.length > 0) {
// 						if (title.indexOf(keyword) == -1) {
// 							ok	= false;
// 						}
// 					}
// 					
// 					if (ok) {
// 						add_dataset(w);
// 					}
// 				}
// 			}
//		});
//		return false;
//	})    
//});
