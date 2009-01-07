// gather any query parameters into a ColdFusion-like hash (ex: http://active.com?query=marathon&start=10  =>  { query:marathon,start:10 })
var url = {};
window.location.search.replace(/([^?=&]+)(=([^&]*))?/g, function($0,$1,$2,$3) { url[$1] = $3 });

// Add an array of outstanding requests to the Ajax object
Ajax.uniqueIdentifiers = 0;
Ajax.currentRequests = $A([]);

Ajax.Responders.register({
  // when a request goes out, add it to the array
  onCreate: function(request) {
    request.id = Ajax.uniqueIdentifiers++;
		Ajax.currentRequests[request.id] = request;
	},
	// when a request returns, null it out
	onComplete:function(request) {
	  Ajax.currentRequests[request.id] = null;
  }
});

function handleEnter(form,e) {
	var keycode;
	if (window.event) {
		keycode = window.event.keyCode;
	} else if (e) {
		keycode = e.which;
	} else {
		return true;
	}

	if (keycode == 13) {
		form.submit();
		return false;
	} else {
		return true;
	}
}

function switchSearch(type) {
	// turn off all searches
	$$('#search_refine .tab').each(function(tab) {
		tab.hide();
	});
	// turn off all tabs
	$$('#search_tabs li').each(function(tab) {
		tab.removeClassName('selected');
	});

	// show selected search and highlight selected tab
	$(type+'_search').show();
	$(type+'_tab').addClassName('selected');
}

function sort(sort_by) {
  var query_string = '?'
  query_string += 'sort=' + sort_by;
  
  $H(url).each(function(pair) {
    if(pair.first() != 'sort') {
      query_string += '&' + pair.first() + '=' + pair.last();
    }
  });
  
  // alert(query_string);
  location.href = query_string;
}

// select a value in a dropdown
function selectOption(obj, value) {
	if($(obj)) {
		$A($(obj).options).find(function(option) {
			if(option.value.toLowerCase() == value.toLowerCase()) {
				option.selected = true;
			}
		});
	}
}

// Add a tip to the bottom of the calendar by extending the exist library
CalendarDateSelect.prototype.__initCalendarDiv = CalendarDateSelect.prototype.initCalendarDiv;
Object.extend(CalendarDateSelect.prototype, {
	initCalendarDiv:function() {
		this.__initCalendarDiv();
		this.calendar_div.insert({bottom:'<div class="tips"><strong>Tip:</strong> Next time try just typing something like "next month", "july" or "today"</div>'});
	}
});		


// asset sports and types
var assets = [
 	{	text:'Any',
 		types: [
 		  { text:'Any' },
 			{	text:'Camp' },
			{	text:'Class' },
			{	text:'Conference' },
			{	text:'Event' },
			{	text:'Membership' },
			{	text:'Program' },
			{	text:'Tee Time' },
			{	text:'Tournament' }
 		]
 	},
	{	text:'Baseball',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Basketball',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Camping',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{ text:'Event' },
			{	text:'Tournament' }
		]
	},
	{	text:'Cycling',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{ text:'Event' },
			{	text:'Membership' }
		]
	},
	{	text:'Fishing',
		types: [
		  { text:'Any' },
			{	text:'Event' },
			{	text:'Tournament' }
		]
	},
	{	text:'Football',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Golf',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Hockey',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Lacrosse',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},		
	{	text:'Running',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event', hasResults:true,
				custom:	{	
					name:'Distance', values: [
					  { text:'Any', value:'' },
						{	text:'5k' },
						{	text:'10k' },
						{	text:'15k' },
						{	text:'1 mile' },
						{	text:'5 mile' },
						{	text:'10 mile' },
						{	text:'Half Marathon' },
						{	text:'Marathon' },
						{	text:'Ultra Marathon' },
						{	text:'Sprint' },
						{	text:'Fun Run' },
						{	text:'All Womens' },
						{	text:'Kids Run' },
						{	text:'Kids Triathlon' },
						{	text:'Olympic/International' }
					]
				}
			},
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Soccer',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Softball',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Swimming',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Tennis',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'League' },
			{	text:'Membership' },
			{	text:'Tournament'	}
		]
	},
	{	text:'Triathlon',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' },
			{	text:'Membership' }
		]
	}
];