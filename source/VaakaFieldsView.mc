//
// VaakaFields - displays paddle cadence data and paddle meters per second as 1x2 Fields from device
//
// (c) 2022, 2023 Jeff Parker 
//


import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Ant;
import Toybox.FitContributor;
import Toybox.Graphics;
using Toybox.Application.Properties as Properties;


class VaakaFieldsView extends WatchUi.DataField {

    private const BORDER_PAD = 4;

    private const _fonts as Array<Graphics.FontDefinition> = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE,
             Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_THAI_HOT] ;

    // Label Variables
    private var _labelCadence as String = "STROKES";
    private var _labelMPS as String = "MPS";
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
    private var _dataFont as Graphics.FontType = Graphics.FONT_XTINY;
    private var _dataFontAscent as Number = 0;

    // field separator line
    private var _separator as Array<Number>?;

    private var _sensor as VaakaSensor;
    private var _sensorOpen as Boolean = false;

    private var _xCenter as Number = 0;
    private var _yCenter as Number = 0;

    // FIT fields
    const CADENCE_FIELD_ID = 0;
    const MPS_FIELD_ID = 1;
    private var cadenceField as FitContributor.Field;
    private var mpsField as FitContributor.Field;

    // rolling average
    const AVERAGE_WINDOW = 5;
    private var _RAcurrentPosition as Number = 0;
    private var _RAcurrentSum as Float = 0.0;
    private var _rollingAverage as Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0];

    // paddle cadence levels - defaults
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
    public function initialize() {

        DataField.initialize();


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
       
        _sensor = new VaakaSensor();

        // load Cadence defaults
        _recovery = Properties.getValue("recovery") ;
        _tempo = Properties.getValue("tempo") as Number;
        _endurance = Properties.getValue("endurance") as Number;
        _threshold = Properties.getValue("threshold") as Number;
        _v02max = Properties.getValue("v02max") as Number;
        
/*
        <property id="recovery" type="number">0</property>
        <property id="endurance" type="number">32</property>
        <property id="tempo" type="number">36</property>
        <property id="threshold" type="number">38</property>
        <property id="v02max" type="number">44</property>
       
        */
    }


    // Called from VaakaFieldsApp.onStart()
    public function onStart() as Void {
        
        try {
            if (_sensor != null && _sensor.open() == true) {
                _sensorOpen = true;
                //System.println("sensor open");
            }
        } catch(e instanceof Lang.Exception) {
            System.println("*** No more ant channels: "+e.getErrorMessage());
        }
    }

    // Called from VaakaFieldsApp.onStop()
    public function onStop() as Void {
        if (_sensor != null) {
            _sensor.close();
        }
    }


    // Called from VaakaFieldsApp.onSettingsChanged()
    public function onSettingsChanged() as Void {
        // load Cadence defaults
        _recovery = Properties.getValue("recovery") as Number;
        _tempo = Properties.getValue("tempo") as Number;
        _endurance = Properties.getValue("endurance") as Number;
        _threshold = Properties.getValue("threshold") as Number;
        _v02max = Properties.getValue("v02max") as Number;
        WatchUi.requestUpdate();   // update the view to reflect changes
    }


    private function RollingAverage(newValue as Float) as Float {

         //Subtract the oldest number from the prev sum, add the new number
        _RAcurrentSum = _RAcurrentSum - _rollingAverage[_RAcurrentPosition] + newValue;

        //Assign the newValue to the position in the array
        _rollingAverage[_RAcurrentPosition] = newValue;

        _RAcurrentPosition = _RAcurrentPosition + 1;
        
        if (_RAcurrentPosition >= AVERAGE_WINDOW-1) { // Don't go beyond the size of the array...
            _RAcurrentPosition = 0;
        }
                
        //return the average
        return _RAcurrentSum / AVERAGE_WINDOW;
    }
    


    var _previousCadence as Number = 0;
    private function recordCadence(value as Number) as Void{
        if (value != _previousCadence){
            _previousCadence = value;
            cadenceField.setData(value);
        }
    }

    var _previousMPS as Float = 0.0;
    private function recordMPS(value as Float) as Void{
        if (value != _previousMPS){
            if (value < 2.0*RollingAverage(value)){
                _previousMPS = value;
                mpsField.setData(value);
            }
        }
    }

    //! Update Speed data for MPS computations
    //! @param info The updated Activity.Info object
    public function compute(info as Info) as Void {
        if (info has :currentSpeed){
            if (info.currentSpeed != null){
                _sensor.calculateMPS(info.currentSpeed) as Float;
            }
        }     
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
        //var size = Graphics.getFontAscent(_fonts[hLayoutFontIdx]);
            
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
            var x = (width/2) as Number;
            var y1 = top + BORDER_PAD as Number;
            var y2 = height - BORDER_PAD as Number;
            _separator = [x, y1, x, y2] as Array<Number>;

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
            _separator = [(width * 0.85) as Number, dc.getHeight()*0.3 as Number, (width * 0.85) as Number, dc.getHeight()*0.6 as Number] as Array<Number>;
        }

        _xCenter = dc.getWidth() / 2;
        _yCenter = dc.getHeight() / 2;
    }

    //! Get the largest font that fits in the given width and height
    //! @param dc Device context
    //! @param width Width to fit in
    //! @param height Height to fit in
    //! @return Index of the font that fits
    private function selectFont(dc as Dc , width as Number, height as Number) as Number {
        var testString = "8.8"; // Dummy string to test data width
        var fontIdx;

        // Search through fonts from biggest to smallest
        for (fontIdx = (_fonts.size() - 1); fontIdx > 0; fontIdx--) {
            var dimensions = dc.getTextDimensions(testString, _fonts[fontIdx]) as Lang.Array<Lang.Number>;
            //var size = Graphics.getFontAscent(_fonts[fontIdx]);
            _dataFontAscent = dimensions[1] as Number;
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
        else if (_sensorOpen == false) {
            dc.drawText(_xCenter, _yCenter, Graphics.FONT_MEDIUM, "No Vaaka Sensor", Graphics.TEXT_JUSTIFY_CENTER);
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
            var CadenceCount; //as String;
            var MPSValue; // as String;
            var sensorData; // as VaakaData;
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
    private function showCadenceIntensity(dc as Dc,x as Number,y as Number,height as Number,cadence as Number) as Void {

        // set default colours
        var bgColor = getBackgroundColor();
        var fgColor = Graphics.COLOR_WHITE;

        if (bgColor == Graphics.COLOR_WHITE) {
            fgColor = Graphics.COLOR_BLACK;
        }


        // draw guage
        var segmentHeight = height/4;
        dc.setColor(fgColor, fgColor);

        // draw segments
       
        var thisY = y - segmentHeight  ;

        for (var i = 1; i < 5; i++) {
            // draw elements
            thisY = thisY + segmentHeight;
            if (i != 1 && i != 4){
               // dc.drawRectangle(x-8, thisY, 17, segmentHeight + 1);
            }

            var colour = getSegmentColour(i,cadence);
            dc.setColor(colour, colour);
            dc.fillRectangle(x-7, thisY+1, 14, segmentHeight-2);
            dc.setColor(fgColor, bgColor);
            
        }
         thisY = y - segmentHeight  ;
        for (var i = 1; i < 5; i++) {
            // draw elements
            thisY = thisY + segmentHeight;
       
            // dc.drawRectangle(x-8, thisY, 17, segmentHeight + 1);
            
        }


        // draw outside rectangle
        //dc.drawRoundedRectangle(x-8, y, 17, segmentHeight*4, 2);
    }

    //! draw segment colour based on intensity score
    private function getSegmentColour(segment as Number,cadence as Number) as Graphics.ColorValue {
        var fillColor = Graphics.COLOR_LT_GRAY;
        var _intensity = cadence;
        
        if (null != _intensity ) {     
            switch(segment){
                case 4: 
                    if (_intensity < 1){
                        // no paddle
                        fillColor = Graphics.COLOR_LT_GRAY;
                    }
                    if ( _intensity >= _recovery) {
                        // recovery
                        fillColor = Graphics.COLOR_DK_GRAY;
                    }
                    if (_intensity >= _endurance) {
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