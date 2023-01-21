//
// VaakaSensor - reads paddle cadence data and calculates paddle meters per second from device
// based on:
//  ANT+ profile: https://www.thisisant.com/developer/ant-plus/device-profiles/#523_tab
//  Spec sheet: https://www.thisisant.com/resources/bicycle-speed-and-cadence/
//
// (c) 2022 Jeff Parker 
//

import Toybox.ActivityRecording;
import Toybox.Ant;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class VaakaData {
        private var _cadence as Number;
        private var _cadenceCount as Number;
        private var _cadenceEventTime as Long;
        private var _mps as Float;        

        //! Constructor
        public function initialize() {
            _cadence = 0;
            _cadenceCount =0;
            _cadenceEventTime = 0;
            _mps = 0.0;
        }

        //! Get the current Cadence
        //! @return cadence
        public function getCadence() as Numeric {
            return _cadence;
        }

        //! Get the current Cadence
        //! @cadence new cadence value
        public function setCadence(cadence) {
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


            var oldCadenceTime = _cadenceEventTime;
            var oldCadenceCount as Number = _cadenceCount;
            var cadenceCount as Number = payload[6] + payload[7]<<8;
            var cadenceTime as Number = payload[4] + payload[5]<<8;

            if (cadenceTime != oldCadenceTime) {
                _cadenceEventTime = cadenceTime;
                _cadenceCount = cadenceCount;

                
                if (oldCadenceTime > cadenceTime) { //Hit rollover value
                    cadenceTime += (1024 * 64);
                }
                
                /* never rolls over for Vakka
                if (oldCadenceCount > cadenceCount) { //Hit rollover value
                    cadenceCount += (1024 * 64);
                }
                */
                
                var newCadence = ((60 * (cadenceCount - oldCadenceCount) * 1024) / (cadenceTime - oldCadenceTime));
                if (newCadence != null) {
                    _cadence = newCadence;
                }
            }

            // update screen
            WatchUi.requestUpdate();
            
        }

        // Calcuate MPS
        // @currentSpeed in Meters per second
        public function calculateMPS(currentSpeed as Float) as Void {
            if (currentSpeed == null) {
                return;
            }
            var distance = currentSpeed * 60.0;
            if (_cadence > 0 && distance > 0){
                _mps = distance/_cadence;
            }
            else {
                _mps = 0;
            }         
        }
    }

class VaakaSensor extends Ant.GenericChannel {
    //! Page number for the message type we care about
    private const PAGE_NUMBER = 1;

    private const DEVICE_TYPE = 0x7A;//120;
    private const PERIOD = 8102;//8192;

    private var _chanAssign as ChannelAssignment;
    private var _deviceCfg as DeviceConfig;
    private var _isPaired as Boolean;
    private var _isClosed as Boolean;
    private var _isSending as Boolean;

    private var _data as VaakaData;
    private var _deviceNumber as Number;

    //private var _proximityPairing;

    //! Constructor
    public function initialize() {

        // Get the channel
        _chanAssign = new Ant.ChannelAssignment(Ant.CHANNEL_TYPE_RX_NOT_TX, Ant.NETWORK_PLUS);
        GenericChannel.initialize(method(:onMessage), _chanAssign);

        // set device number to search
        _deviceNumber = 0;
        //_deviceNumber = Application.getApp().getProperty("deviceNumber");
        //_proximityPairing = Application.getApp().getProperty("proximityPairing");

        // Set the configuration
        _deviceCfg = new Ant.DeviceConfig({
            :deviceNumber => 0,                 // Wildcard our search
            :deviceType => DEVICE_TYPE,
            :transmissionType => 0,
            :messagePeriod => PERIOD,
            :radioFrequency => 57,              // Ant+ Frequency
            :searchTimeoutLowPriority => 10,    // Timeout in 25s
            :searchThreshold => 0});            // Pair to all transmitting sensors
        GenericChannel.setDeviceConfig(_deviceCfg);

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
        var open = GenericChannel.open();
        _isClosed = false;
        _isSending = false;

        // initialize cadence data
        _data = new VaakaData();
        return open;
    }

    //! Close the ANT sensor and save the session
    public function closeSensor() as Void {
        _isClosed = true; 
        _isSending = false;  
        GenericChannel.close();
    }

    //! Update when a message is received
    //! @param msg The ANT message
    public function onMessage(msg as Message) as Void {

        _deviceCfg = GenericChannel.getDeviceConfig();
        var payload = msg.getPayload();

        if ((Ant.MSG_ID_BROADCAST_DATA == msg.messageId)){
            // Were we searching?
            _isSending = true;   // device Transmitting data

            // Were we searching?
            if ( !_isPaired ) {
                _isPaired = true;    // Only fire paired event once

                _deviceNumber = msg.deviceNumber;
               
                // Update our device configuration primarily to see the device number of the sensor we paired to
                _deviceCfg = GenericChannel.getDeviceConfig();
            }

            // get the device payload
            _data.parse(payload);

        } else if ((Ant.MSG_ID_CHANNEL_RESPONSE_EVENT == msg.messageId) && (Ant.MSG_ID_RF_EVENT == (payload[0] & 0xFF))) {
            // handle RF Event
            //System.println( Lang.format("RF event:$1$", [payload[1].format("%x")] ) );
            switch((payload[1] & 0xFF)){
            // Close event occurs after a search timeout or if it was requested

            case Toybox.Ant.MSG_CODE_EVENT_CHANNEL_CLOSED:
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
        }
    }

    //! Get the data for this sensor
    //! @return Data object
    public function getData() {
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