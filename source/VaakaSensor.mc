//
// VaakaSensor - reads paddle cadence data and calculates paddle meters per second from device
// based on:
//  ANT+ profile: https://www.thisisant.com/developer/ant-plus/device-profiles/#523_tab
//  Spec sheet: https://www.thisisant.com/resources/bicycle-speed-and-cadence/
//
// (c) 2022, 2023 Jeff Parker 
//

import Toybox.ActivityRecording;
import Toybox.Ant;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application;

class VaakaData {
        private var _cadence as Number;
        private var _cadenceCount as Number;
        private var _cadenceEventTime as Number;
        private var _mps as Float;  
        private var _togglePage as Boolean = false;   

        private var _staleCadenceCount as Number;

        //! Constructor
        public function initialize() {
            _cadence = 0;
            _cadenceCount = 0;
            _cadenceEventTime = 0;
            _mps = 0.0;
            _staleCadenceCount = 0;          
        }

        //! Get the current Cadence
        //! @return cadence
        public function getCadence() as Number {
            return _cadence;
        }

        //! Get the current Cadence
        //! @cadence new cadence value
        public function setCadence(cadence as Number) as Void {
            _cadence  = cadence ;
        }

        //! Get the current Meters per Stroke
        //! @return mps
        public function getMPS() as Float {
            return _mps;
        }

    
        //! Parse the payload to get the current data values
        //! @param payload ANT data payload
        public function parse(payload as Array<Number>) as Void {

            var page = payload[0];
            var oldCadenceTime = _cadenceEventTime;
            var oldCadenceCount = _cadenceCount;
            var cadenceCount = payload[6] + payload[7]<<8;
            var cadenceTime = payload[4] + payload[5]<<8;
            
            // Calculate cadence
            if (cadenceTime != oldCadenceTime) {
                _cadenceEventTime = cadenceTime;
                _cadenceCount = cadenceCount;
                _staleCadenceCount = 0;  
                
                if (oldCadenceTime > cadenceTime) { //Hit rollover value
                    cadenceTime += (1024 * 64);
                }
                
               
                if (oldCadenceCount > cadenceCount) { //Hit rollover value
                    cadenceCount += (1024 * 64);
                }
                
                var newCadence = ((60 * (cadenceCount - oldCadenceCount) * 1024) / (cadenceTime - oldCadenceTime));
                if (newCadence != null) {
                    _cadence = newCadence;
                }
                if (_cadence < 0){  // shouldn't happen
                    _cadence = 0;
                }

                
            } else {
                _staleCadenceCount = _staleCadenceCount + 1 ;
            }

            // check for stop padding
            if (_staleCadenceCount > 7){
                _cadence = 0;
            }
            //System.println(Lang.format("Count [$1$] Time [$2$] Cadence [$3$] Stale[$4$]",[_cadenceCount.format("%d"),_cadenceEventTime.format("%d"),_cadence.format("%d"),_staleCadenceCount.format("%d")]));

            // update screen
            WatchUi.requestUpdate();

            // process the toggle bit page value 
            if (!_togglePage){
                _togglePage = ((page & 0x80)) > 0;  // true if MSB bit is set 
            }
            
            // last 7 bits has data page number
            if ((page & ~0x80) == 2 && _togglePage){
                // Data page 2 - Manufacturer ID
                var serialNumber = payload[2] | (payload[3] << 8 );
                Application.Properties.setValue("serialNumber",serialNumber);
                // not interested in page 3, 4, 5
            }
        }

        // Calcuate MPS
        // @currentSpeed in Meters per second
        public function calculateMPS(currentSpeed as Float or Null) as Void {
            if (currentSpeed == null) {
                _mps = 0.0;
            }
            else {
                var distance = currentSpeed * 60.0;
                if (_cadence > 0 && distance > 0){
                    _mps = distance/_cadence;
                }
                else {
                    _mps = 0.0;
                }  
            }       
        }
    }

class VaakaSensor {

    private const DEVICE_TYPE = 0x7A;//120;
    private const PERIOD = 8102;//8192;

    public var _deviceCfg as DeviceConfig?;
    private var _channel as Ant.GenericChannel?;
    private var _isPaired as Boolean;
    private var _isClosed as Boolean;
    private var _isSending as Boolean;

    private var _data as VaakaData;
    private var _deviceNumber as Number = 0;
    


    

    //private var _proximityPairing;

    //! Constructor
    // Initializes AntPlusHeartRateSensor, configures and opens channel
    public function initialize() {

        // set the data class
        _data = new VaakaData();

        // The channel has not paired with a device yet
        _isPaired = false;

        // The channel is not open
        _isClosed = true;

        // No data yet
        _isSending = false;
    }

    //! Open an ANT channel
    //! @return true if channel opened successfully, false otherwise
    public function open() as Boolean {

        // Open the channel
        _isClosed = false;
        _isSending = false;
        _isPaired = false;

        // Get the channel
        var chanAssign = new Ant.ChannelAssignment(Ant.CHANNEL_TYPE_RX_NOT_TX, Ant.NETWORK_PLUS);

        // Initialize the channel through the superclass
        try {
            _channel = new Ant.GenericChannel(method(:onMessage), chanAssign);
        } catch (e) {
            System.println(e.getErrorMessage());
        }

         //System.println("Generic channel initialised");
        // set device number to search
        _deviceNumber = Application.Properties.getValue("deviceNumber") as Number;
        //_proximityPairing = Application.getApp().getProperty("proximityPairing");

        //System.println(Lang.format("Device number=$1$",[_deviceNumber.format("%d")]));

        // Set the configuration
        _deviceCfg = new Ant.DeviceConfig({
            :deviceNumber => _deviceNumber,                 // Wildcard our search
            :deviceType => DEVICE_TYPE,
            :transmissionType => 0,
            :messagePeriod => PERIOD,
            :radioFrequency => 57,              // Ant+ Frequency
            :searchTimeoutLowPriority => 10,    // Timeout in 25s
            :searchThreshold => 0});            // Pair to all transmitting sensors
        
        if (_channel != null){
            _channel.setDeviceConfig(_deviceCfg);
        }

        if (_channel != null && _channel.open() == true){
            return true;
        }
        else {
            System.println("Channel not open");
            return false;
        }
    }

    //! Close the ANT sensor and save the session
    public function close() as Void {
        _isClosed = true; 
        _isSending = false;  
        var channel = _channel;
        if (channel != null) {
            _channel = null;
            channel.release();
        }
    }

    //! Update when a message is received
    //! @param msg The ANT message
    public function onMessage(msg as Message) as Void {

        if (_channel != null){
            _deviceCfg = _channel.getDeviceConfig();
        }
        var payload = msg.getPayload();

        //var page = payload[0] & ~0x80;
        //System.println(Lang.format("page=[$1$]",[page.format("%x")]) );

        //System.println(Lang.format("messageResponse=[$1$]",[msg.messageId.format("%x")]) );
        //var code = payload[0] & 0xfe;
        //System.println(Lang.format("messageID=[0x$1$]",[code.format("%x")]) );
        //System.println(Lang.format("messageCode=[0x$1$]",[payload[1].format("%x")]) );
        if ((Ant.MSG_ID_BROADCAST_DATA == msg.messageId)){
            //System.println(Lang.format("[0x$1$] MSG_ID_BROADCAST_DATA Page [0x$2$]",[msg.messageId.format("%x"),page.format("%x")]));

            // Were we searching?
            _isSending = true;   // device Transmitting data

            // Were we searching?
            if ( !_isPaired ) {
                _isPaired = true;    // Only fire paired event once

                _deviceNumber = msg.deviceNumber;
               
                // Update our device configuration primarily to see the device number of the sensor we paired to
                if (_channel != null){
                    _deviceCfg = _channel.getDeviceConfig();
                }
                //System.println(Lang.format("Device number=$1$",[_deviceNumber.format("%d")]));
                Application.Properties.setValue("deviceNumber",_deviceNumber);
            }

            // get the device payload
            _data.parse(payload);

        } else if ((Ant.MSG_ID_CHANNEL_RESPONSE_EVENT == msg.messageId) && (Ant.MSG_ID_RF_EVENT == (payload[0] & 0xFF))) {
            // handle RF Event
            //System.println(Lang.format("[0x40 MSG_ID_CHANNEL_RESPONSE_EVENT event: MSG_ID_RF_EVENT code: [0x$1$]",[payload[1].format("%x")]));
            switch((payload[1] & 0xFF)){
            // Close event occurs after a search timeout or if it was requested

            case Toybox.Ant.MSG_CODE_EVENT_CHANNEL_CLOSED:
                // System.println("MSG_CODE_EVENT_CHANNEL_CLOSED");
                // Reset Cadence data after the channel closes
                _data.setCadence(0);

                // If ANT closed the channel, re-open it to continue pairing
                if(!_isClosed) {
                    open();
                }
                break;

            // Search timeout occurs after SEARCH_TIMEOUT duration passes without pairing
            case Toybox.Ant.MSG_CODE_EVENT_RX_SEARCH_TIMEOUT:
                // set cadence to zero
                //System.println("MSG_CODE_EVENT_RX_SEARCH_TIMEOUT");
                _data.setCadence(0);
                break;

            // Drop to search occurs after 2s elapse or 8 RX_FAIL events, whichever comes first
            case Toybox.Ant.MSG_CODE_EVENT_RX_FAIL_GO_TO_SEARCH:
                // Reset Cadence data after missing over 2s of messages
                //System.println("MSG_CODE_EVENT_RX_FAIL_GO_TO_SEARCH");
                _data.setCadence(0);
                break;
            
            }
        } else {
            //System.println(Lang.format("Other =[0x$1$]",[msg.messageId.format("%x")]) );

        }
    }

    //! Get the data for this sensor
    //! @return Data object
    public function getData() as VaakaData {
        return _data;
    }

    //! Get the device config for this channel
    //! @return Device config object
    public function getDeviceConfig() as DeviceConfig {
        return _deviceCfg;
    }

    //! Get whether the channel is paired
    //! @return true if searching, false otherwise
    public function isPaired() as Boolean {
        return _isPaired;
    }

    //! Get whether the channel is open
    //! @return true if open, false otherwise
    public function isClosed() as Boolean {
        return _isClosed;
    }

    //! Get whether the device is sending data
    //! @return true if sending, false otherwise
    public function isSending() as Boolean {
        return _isSending;
    }

    // Calcuate MPS
    // @currentSpeed in Meters per second
    public function calculateMPS(currentSpeed as Float) as Void {
        _data.calculateMPS(currentSpeed);
    }
}