// Get some ajax from a related search back from the server and update the result on the page

var Related = new Class.create();
Related.prototype = {
	
	initialize:function() {
	},
	
	parse:function(r) {
		var response = r.responseText.evalJSON();
    var id = response.id
    var results = $A(response.results);
		var at_least_one_result = false;

    results.each(function(result) {
			if(result.value > 0 || result.value != '') {
      	if ($('result_'+id+'_links_'+result.name)) {
					var this_noun = result.value != 1 ? result.noun + 's' : result.noun;
					$('result_'+id+'_links_'+result.name).update('<a href="' + result.link + '">' + result.value + ' ' + this_noun + '</a>');
					at_least_one_result = true;
				}
			}
    });
		$('result_'+id+'_indicator') ? $('result_'+id+'_indicator').remove() : null;
		at_least_one_result ? $('result_'+id+'_links').show() : null;
	}
	
}