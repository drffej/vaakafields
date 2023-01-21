//
// VaakaFields - reads paddle cadence data from Vaaka device and calculate paddle meters per second.
//   display as two data fields on Garmin device
// (c) 2022 Jeff Parker 
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class VaakaFieldsApp extends Application.AppBase
{
    private var _sensor as VaakaSensor;

    function initialize() {
        AppBase.initialize();
        _sensor = new $.VaakaSensor();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {

        // open Vaaka sensor
        _sensor.open();

    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        // Release the Vaaka sensor
        _sensor.closeSensor();
        _sensor.release();
    }

    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
        return [ new VaakaFieldsView(_sensor)] as Array<Views or InputDelegates>;
    }

}

function getApp() as VaakaFieldsApp {
    return Application.getApp() as VaakaFieldsApp;
}