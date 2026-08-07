import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import Application

ApplicationWindow {
    id: win
    visible: false
    width: 1; height: 1

    AlertManager {
        id: alertManager
        Component.onCompleted: startPolling()
    }

    Component {
        id: alertWindowComponent
        AlertWindow {
            onDismiss: {
                alertManager.dismissAlert()
                var idx = openAlertWindows.indexOf(this)
                if (idx !== -1) openAlertWindows.splice(idx, 1)
                visible = false
                destroy()
            }
        }
    }

    Component {
        id: settingsWindowComponent
        SettingsWindow {}
    }

    property var openAlertWindows: []
    property var settingsWindow: null

    function openSettings() {
        if (settingsWindow) {
            settingsWindow.raise()
            return
        }
        settingsWindow = settingsWindowComponent.createObject(null)
        settingsWindow.onVisibilityChanged.connect(function() {
            if (!settingsWindow.visible) {
                settingsWindow.destroy()
                settingsWindow = null
            }
        })
        settingsWindow.visible = true
    }

    Component.onCompleted: {
        Qt.application.quitOnLastWindowClosed = false
        var svc = Qt.createQmlObject('import Application; ConfigService {}', win)
        if (svc.isFirstRun)
            openSettings()
        svc.destroy()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (alertManager.checkForNewAlerts()) {
                var w = alertWindowComponent.createObject(null)
                w.alertTitle = alertManager.alertTitle
                w.alertDescription = alertManager.alertDescription
                w.alertColor = alertManager.alertColor
                w.alertExpiry = alertManager.alertExpiry
                w.alertSoundPath = alertManager.alertSoundPath
                w.alertSeverity = alertManager.alertSeverity
                w.alertType = alertManager.alertType
                w.visible = true
                openAlertWindows.push(w)
            }
        }
    }

    SystemTrayIcon {
        id: trayIcon
        visible: true
        icon.source: Qt.resolvedUrl("icon.png")
        tooltip: "DeskAlert"

        menu: Menu {
            MenuItem {
                text: "Options"
                onTriggered: openSettings()
            }
            MenuSeparator {}
            MenuItem {
                text: "Quit"
                onTriggered: Qt.quit()
            }
        }

        onActivated: {
            if (reason === SystemTrayIcon.Trigger)
                openSettings()
        }
    }
}
