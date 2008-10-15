// gather any query parameters into a ColdFusion-like hash (ex: http://active.com?query=marathon&start=10  =>  { query:marathon,start:10 })
var url = {};
window.location.search.replace(/([^?=&]+)(=([^&]*))?/g, function($0,$1,$2,$3) { url[$1] = $3 });

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
  
  if(sort_by != 'relevant') {
    query_string += 'sort=' + sort_by;
  }
  
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
			{	text:'Tournament',
				custom: {
					name:'Age Group', values: [
						{	text:'6 and Under' },
						{	text:'7 and Under' },
						{	text:'8 and Under' },
						{	text:'9 and Under' },
						{	text:'10 and Under' },
						{	text:'11 and Under' },
						{	text:'12 and Under' },
						{	text:'13 and Under' },
						{	text:'14 and Under' },
						{	text:'15 and Under' },
						{	text:'16 and Under' },
						{	text:'17 and Under' },
						{	text:'18 and Under' },
						{	text:'High School' },
						{	text:'College' },
						{	text:'Adult' },
						{	text:'Senior' }
					]
				}
			}
		]
	},
	{	text:'Basketball',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Cycling',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Fitness & Nutrition',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Football',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Golf',
		types: [
		  { text:'Any' },
		  { text:'Event'},
			{	text:'Tee Time' },
			{	text:'Tournament' }
		]
	},
	{	text:'Mind & Body',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Outdoors',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Event' }
		]
	},		
	{	text:'Running',
		types: [
		  { text:'Any' },
			{	text:'Event', hasResults:true,
				custom:	{	
					name:'Distance', values: [
					  { text:'Any' },
						{	text:'5k' },
						{	text:'10k' },
						{	text:'15k' },
						{	text:'1 mile' },
						{	text:'5 mile' },
						{	text:'10 mile' },
						{	text:'Half Marathon' },
						{	text:'Marathon' },
						{	text:'Ultra Marathon' },
						{	text:'Spring' },
						{	text:'Fun Run' },
						{	text:'All Womens' },
						{	text:'Kids Run' },
						{	text:'Kids Triathlon' },
						{	text:'Olympic/International' }
					]
				}
			}
		]
	},
	{	text:'Soccer',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Softball',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Tennis',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{ text:'Event'},
			{	text:'Tournament' }
		]
	},
	{	text:'Travel',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Triathlon',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Women',
		types: [
		  { text:'Any' },
			{	text:'Camp' },
			{	text:'Tournament' }
		]
	},
	{	text:'Others',
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
	}
];