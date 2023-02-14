//
// VaakaFields - reads paddle cadence data from Vaaka device and calculate paddle meters per second.
//   display as two data fields on Garmin device
// (c) 2022, 2023 Jeff Parker 
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class VaakaFieldsApp extends Application.AppBase
{
    private var _vaakaField as VaakaFieldsView ;

    function initialize() {
        _vaakaField = new VaakaFieldsView();
        AppBase.initialize();

    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {

        // open Vaaka sensor
        _vaakaField.onStart();

    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        _vaakaField.onStop();
    }

    function onSettingsChanged() {
        _vaakaField.onSettingsChanged();
    }

    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
        return [ _vaakaField ] as Array<Views or InputDelegates>;
    }

}

function getApp() as VaakaFieldsApp {
    return Application.getApp() as VaakaFieldsApp;
}