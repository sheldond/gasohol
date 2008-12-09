var Search = new Class.create();
Search.prototype = {

	initialize:function(assets) {
		// observe the dropdowns
		this.assets = assets;

		$('sport').observe('change', this.changeSport.bindAsEventListener(this));
		$('type').observe('change', this.changeType.bindAsEventListener(this));

		// add sports to the dropdown
		this.build($('sport'), this.assets);

		// call the changeSport() method to populate the types (as if someone had just selected it manually)
		this.changeSport();
	},

	changeSport:function() {
		var selectedSport = this.getSport();

		if (selectedSport) {
			this.build($('type'),selectedSport.types);
		}

		this.changeType();
	},

	changeType:function() {
		var selectedSport = this.getSport();
		var selectedType = this.getType(selectedSport);

		if(selectedType) {

			// show/hide the 'include results' checkbox
			// selectedType.hasResults ? $('results_container').show() : $('results_container').hide();

			// show/hide the custom select box
			if(selectedType.custom) {
				$('custom_label').update(selectedType.custom.name);
				this.build($('custom'), selectedType.custom.values);
				$('custom_container').show();
			} else {
				$('custom_container').hide();
			}
		}
	},

	getSport:function() {
		var sport = $('sport');
		return this.assets.find(function(asset) {
			if(asset.text == sport.value) {
				return asset;
			}
		});
	},

	getType:function(asset) {
		var type = $('type');
		return asset.types.find(function(thisType) {
			if(thisType.text == type.value) {
				return thisType;
			}
		});
	},

	// adds <option>s to a select box
	build:function(obj,values) {
		this.reset(obj);
		// var options = obj.options;
		values.each(function(value) {
			if(value.value || value.value == '') {
				var option = new Option(value.text,value.value);
			} else {
				var option = new Option(value.text,value.text);
			}
			if(Prototype.Browser.IE) {
				obj.add(option);
			} else {
				obj.add(option,null);
			}
		});
	},

	// removes all <option>s from a select box
	reset:function(obj) {
		obj.options.length = 0;
	}

};