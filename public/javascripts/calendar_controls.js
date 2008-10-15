var CalendarControls = new Class.create();
CalendarControls.prototype = {

	options:{	titleformat:'mmmm yyyy',
				dayheadlength:2,
				weekdaystart:0,
				openeffect: Element.show,
				closeeffect: Element.hide
	},

	initialize:function(start,end) {
		start.observe('change',this.manualStartDate.bindAsEventListener(this));
		end.observe('change',this.manualEndDate.bindAsEventListener(this));
	},

	updateStartDate:function(date,toggle) {
		$('start_date').value = date.format('mm/dd/yyyy');
		if(toggle) {
			start_date_cal.toggleCalendar();
		}
	},

	updateEndDate:function(date,toggle) {
		$('end_date').value = date.format('mm/dd/yyyy');
		if(toggle) {
			end_date_cal.toggleCalendar();
		}
	},

	manualStartDate:function(event) {
		start_date_cal.setCurrentDate(new Date(event.element.value));
	},

	manualEndDate:function(event) {
		end_date_cal.setCurrentDate(new Date(event.element.value));
	}

};