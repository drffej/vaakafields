//
// VaakaFields - displays paddle cadence data and paddle meters per second as 1x2 Fields from device
//
// (c) 2022 Jeff Parker 
//


import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Ant;
using Toybox.Application.Properties as Properties;


class VaakaFieldsView extends WatchUi.DataField {

    private const BORDER_PAD = 4;
    private const UNITS_SPACING = 2;

    private const _fonts as Array<FontDefinition> = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE,
             Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_THAI_HOT] as Array<FontDefinition>;

    // Label Variables
    private var _labelCadence = "STROKES";
    private var _labelMPS = "MPS";
    private const _labelFont = Graphics.FONT_XTINY;
    private const _labelY = 1;
    private var _labelX as Number = 0;
    private var _labelCadenceX as Number  = 0;
    private var _labelCadenceY as Number = 0;
    private var _labelMPSX as Number = 0;
    private var _labelMPSY as Number = 0;

    // Cadence variables
    private var _CadenceX as Number = 0;
    private var _CadenceY as Number = 0;

    // Meters per Stoke variables
    private var _MPSX as Number = 0;
    private var _MPSY as Number = 0;

    // Font values
    private const _unitsFont = Graphics.FONT_XTINY;
    private var _dataFont as FontDefinition = Graphics.FONT_XTINY;
    private var _dataFontAscent as Number = 0;

    // field separator line
    private var _separator as Array<Number>?;

    private var _sensor as VaakaSensor?;
    private var _xCenter as Number = 0;
    private var _yCenter as Number = 0;

    // FIT fields
    const CADENCE_FIELD_ID = 0;
    const MPS_FIELD_ID = 1;
    private var cadenceField = null;
    private var mpsField = null;

    // rolling average
    const AVERAGE_WINDOW = 5;
    
    private var _RAcurrentPosition = 0;
    private var _RAcurrentSum = 0;
    private var _rollingAverage as Array<Number>;

    // paddle cadence levels
    private var _recovery as Number = 28;
    private var _endurance as Number = 32;
    private var _tempo as Number = 36;
    private var _threshold as Number = 38;
    private var _v02max as Number = 44;

    //Suffer Score Values
    //hidden var _lastMeasuredSufferTime = 0;
    //private var _intensity = null;

    //! Constructor
    //! @param sensor The ANT channel and data
    public function initialize(sensor as VaakaSensor?) {

        // Create the custom FIT data field we want to record for paddling.
        cadenceField = createField(
            "cadence",
            CADENCE_FIELD_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"B"}
        );
        mpsField = createField(
            "mps",
            MPS_FIELD_ID,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"B"}
        );

        cadenceField.setData(0.0);
        mpsField.setData(0.0);
        DataField.initialize();
        _sensor = sensor;

        // load Cadence defaults
        _recovery = Properties.getValue("recovery");
        _tempo = Properties.getValue("tempo");
        _endurance = Properties.getValue("endurance");
        _threshold = Properties.getValue("threshold");
        _v02max = Properties.getValue("v02max");
        
/*
<property id="recovery" type="number">0</property>
        <property id="endurance" type="number">32</property>
        <property id="tempo" type="number">36</property>
        <property id="threshold" type="number">38</property>
        <property id="v02max" type="number">44</property>
        var mySetting = Properties.getValue("appVersion");
        System.println("before");
        System.println(mySetting);
        System.println("after:");
        Properties.setValue("appVersion","newone");
        mySetting = Properties.getValue("appVersion");
        System.println(mySetting);
        */
    }


    private function RollingAverage(newValue as Number) as Number {
        var _rollingAverage as Array<Number>?;
        var _RAcurrentPosition as Number = 0;
        var _RAcurrentSum as Number = 0;

         //Subtract the oldest number from the prev sum, add the new number
        //_RAcurrentSum = _RAcurrentSum - _rollingAverage[_RAcurrentPosition] + newValue;

        //Assign the newValue to the position in the array
        _rollingAverage[_RAcurrentPosition] = newValue;

        _RAcurrentPosition++;
        
        if (_RAcurrentPosition >= AVERAGE_WINDOW-1) { // Don't go beyond the size of the array...
            _RAcurrentPosition = 0;
        }
                
        //return the average
        return _RAcurrentSum / AVERAGE_WINDOW;
    }


    var _previousCadence = 0;
    private function recordCadence(value){
        if (value != _previousCadence){
            _previousCadence = value;
            cadenceField.setData(value);
        }
    }

    var _previousMPS = 0;
    private function recordMPS(value){
        if (value != _previousMPS){
            //if (value < 2*RollingAverage(value)){
                _previousMPS = value;
                mpsField.setData(value);
           // }
        }
    }

    //! Update Speed data for MPS computations
    //! @param info The updated Activity.Info object
    public function compute(info as Info) as Void {
        _sensor.calculateMPS(info.currentSpeed);
    }

    //! Display Cadence and MPS data fields
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var top = _labelY + Graphics.getFontAscent(_labelFont) + BORDER_PAD;

        // Center the field label
        _labelX = width / 2;

        // Compute data width/height for both layouts
        var hLayoutWidth = (width - (2 * BORDER_PAD)) / 2;
        var hLayoutHeight = height ;

        //var hLayoutFontIdx = selectFont(dc, 150, hLayoutHeight);
        var hLayoutFontIdx = selectFont(dc, hLayoutWidth, hLayoutHeight);
        var size = Graphics.getFontAscent(_fonts[hLayoutFontIdx]);
            
        //System.println(Lang.format("set size $1$ h=$2$ h2=$3$ size=$4$",[hLayoutFontIdx.format("%d"), height.format("%d"), hLayoutHeight.format("%d"),size.format("%d")] ) );

        
        var vLayoutWidth = width - (2 * BORDER_PAD);
        var vLayoutHeight = (height -  (3*BORDER_PAD))/2;
        var vLayoutFontIdx = selectFont(dc, vLayoutWidth, vLayoutHeight);
        
        // Use the horizontal layout if it supports a larger font
        if (hLayoutFontIdx > vLayoutFontIdx) {

            // set label positions
            _labelCadenceX = _labelX/2;
            _labelCadenceY = _labelY;
            _labelMPSX = _labelX+_labelX/2;
            _labelMPSY = _labelY;

            // select font
            _dataFont = _fonts[hLayoutFontIdx];
            _dataFontAscent = dc.getFontHeight(_dataFont);

            // Compute the draw location of the Cadence data field
            _CadenceX = BORDER_PAD + (hLayoutWidth / 2);
            _CadenceY = (height - top) / 2 + top - (_dataFontAscent / 2);

            // Compute the center of the MPS Data
            _MPSX = (2 * BORDER_PAD) + hLayoutWidth + (hLayoutWidth / 2);
            _MPSY = _CadenceY;

            // Use a separator line for horizontal layout
            _separator = [(width / 2), top + BORDER_PAD, (width / 2), height - BORDER_PAD] as Array<Number>;

        } else {
            // otherwise, use the vertical layout
            _dataFont = _fonts[vLayoutFontIdx];
            _dataFontAscent = Graphics.getFontAscent(_dataFont);

            _CadenceX = BORDER_PAD + (vLayoutWidth / 2);
            _CadenceY = BORDER_PAD + (vLayoutHeight / 2) - (_dataFontAscent / 2);
            _labelCadenceX = _CadenceX;
            _labelCadenceY = _labelY + Graphics.getFontAscent(_labelFont);

            _MPSX = BORDER_PAD + (vLayoutWidth / 2);
            _MPSY =  2 * BORDER_PAD + vLayoutHeight;
            _labelMPSX = _MPSX;
            _labelMPSY = vLayoutHeight + Graphics.getFontAscent(_labelFont);

            // horizontal separator line for vertical layout
            // _separator = [ 0, dc.getHeight()/2, dc.getWidth(), dc.getHeight()/2 ] as Array<Number>;
            _separator = [(width - 30), dc.getHeight()*0.25, (width - 20), dc.getHeight()*0.75] as Array<Number>;
        }

        _xCenter = dc.getWidth() / 2;
        _yCenter = dc.getHeight() / 2;
    }

    //! Get the largest font that fits in the given width and height
    //! @param dc Device context
    //! @param width Width to fit in
    //! @param height Height to fit in
    //! @return Index of the font that fits
    private function selectFont(dc as Dc, width as Number, height as Number) as Number {
        var testString = "8.8"; // Dummy string to test data width
        var fontIdx;

        // Search through fonts from biggest to smallest
        for (fontIdx = (_fonts.size() - 1); fontIdx > 0; fontIdx--) {
            var dimensions = dc.getTextDimensions(testString, _fonts[fontIdx]);
            var size = Graphics.getFontAscent(_fonts[fontIdx]);
            _dataFontAscent = dimensions[1];
            if ((dimensions[0] <= width) && (dimensions[1] <= height)) {
                break;
            }
        }
        return fontIdx;
    }

    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        var fgColor = Graphics.COLOR_WHITE;

        if (bgColor == Graphics.COLOR_WHITE) {
            fgColor = Graphics.COLOR_BLACK;
        }

        dc.setColor(fgColor, bgColor);
        dc.clear();

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        // Update status
        var sensor = _sensor;
        if (sensor == null) {    
            dc.drawText(_xCenter, _yCenter, Graphics.FONT_MEDIUM, "No Channel!", Graphics.TEXT_JUSTIFY_CENTER);
        } 
        else {

            // change colour to reflect is not sending data
            if (!sensor.isSending()){
                dc.setColor(Graphics.COLOR_RED, bgColor);
            }

            // Draw the field label
            dc.drawText(_labelCadenceX, _labelCadenceY, _labelFont, _labelCadence, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_labelMPSX, _labelMPSY, _labelFont, _labelMPS, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

            // get Cadence and MPS values
            var CadenceCount as String;
            var MPSValue as String;
            var sensorData as VaakaData;
            sensorData = sensor.getData();
            CadenceCount = sensorData.getCadence().format("%d");
            MPSValue = sensorData.getMPS().format("%1.1f");

            // record fit data to log
            recordCadence(sensorData.getCadence());
            recordMPS(sensorData.getMPS());

            // Draw Cadence Field
            dc.drawText(_CadenceX, _CadenceY, _dataFont, CadenceCount, Graphics.TEXT_JUSTIFY_CENTER);

            // Draw MPS Field
            dc.drawText(_MPSX, _MPSY, _dataFont, MPSValue, Graphics.TEXT_JUSTIFY_CENTER);

            // Draw separator or intensity score
            var separator = _separator;
            if (separator != null) {
                dc.setPenWidth(2);
                //dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
                
                if (sensorData.getCadence() != null){
                    showCadenceIntensity(dc,separator[0], separator[1], separator[3]-separator[1], sensorData.getCadence() );
                    //dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
                }
                else {                  
                    dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
                }
            }
        }
    }

    //! Draw bar showing training effect a gauge
    private function showCadenceIntensity(dc,x,y,height,cadence) as Void {

        // set default colours
        var bgColor = getBackgroundColor();
        var fgColor = Graphics.COLOR_WHITE;

        if (bgColor == Graphics.COLOR_WHITE) {
            fgColor = Graphics.COLOR_BLACK;
        }


        // draw guage
         var segmentHeight = height/4;
        dc.drawRoundedRectangle(x-8, y, 17, segmentHeight*4, 2);
        dc.setColor(fgColor, fgColor);

        // draw segments
       
        var thisY = y - segmentHeight  ;

        for (var i = 1; i < 5; i++) {
            // draw elements
            thisY = thisY + segmentHeight;
            if (i != 1 && i != 4){
                dc.drawRectangle(x-8, thisY, 17, segmentHeight + 1);
            }

            var colour = getSegmentColour(i,cadence);
            dc.setColor(colour, colour);
            dc.fillRectangle(x-7, thisY+1, 14, segmentHeight-2);
            dc.setColor(fgColor, bgColor);
        }
    }

    //! draw segment colour based on intensity score
    private function getSegmentColour(segment as Number,cadence) as Graphics.ColorType {
        var fillColor = Graphics.COLOR_WHITE;
        var _intensity = cadence;
        if (null != _intensity ) {     
            switch(segment){
                case 4: 
                    if ( _intensity >= _recovery) {
                        // recovery
                        fillColor = Graphics.COLOR_LT_GRAY;
                    }
                    else if (_intensity >= _endurance) {
                        // endurance
                        fillColor = Graphics.COLOR_BLUE;
                    }
                    break;
                case 3:
                    if (_intensity >= _tempo) {
                        // tempo
                        fillColor = Graphics.COLOR_GREEN;
                    }
                    break;
                case 2:
                    if (_intensity >= _threshold) {
                        // threshold
                        fillColor = Graphics.COLOR_YELLOW;
                    }
                    break;
                case 1:
                    if (_intensity >= _v02max) {
                        // v02max
                        fillColor = Graphics.COLOR_RED;
                    }
                    break;
            }
        }
        return fillColor;
    }

    //! Handle the activity timer starting
    public function onTimerStart() as Void {
    }

    //! Handle the activity timer stopping
    public function onTimerStop() as Void {
        // System.println("timer stop....");
       // _fitContributor.setTimerRunning(false);
    }

    //! Handle an activity timer pause
    public function onTimerPause() as Void {
        // System.println("timer pause");
       // _fitContributor.setTimerRunning(false);
    }

    //! Handle the activity timer resuming
    public function onTimerResume() as Void {
        // System.println("timer resume");
  
    }

    //! Handle a lap event
    public function onTimerLap() as Void {
        
    }

    //! Handle the current activity ending
    public function onTimerReset() as Void {
         //System.println("timer reset");
       // _fitContributor.onTimerReset();
    }

}