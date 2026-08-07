import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

ApplicationWindow {
    id: alertRoot
    palette {
        buttonText: "black"
        text: "white"
        windowText: "white"
        base: "#2a2a2a"
    }
    property string alertTitle: ""
    property string alertDescription: ""
    property string alertColor: "#FF0000"
    property string alertExpiry: ""
    property string alertSoundPath: ""
    property string alertSeverity: ""
    property string alertType: ""
    signal dismiss()

    visible: false
    title: alertType
    width: 500; height: 400
    color: "#1e1e1e"

    onVisibleChanged: {
        if (visible && alertSoundPath !== "") {
            var normalizedPath = alertSoundPath.replace(/\\/g, "/")
            var fileUrl
            if (normalizedPath.match(/^[a-zA-Z]:/)) {
                fileUrl = "file:///" + normalizedPath
            } else if (normalizedPath.charAt(0) === "/") {
                fileUrl = "file://" + normalizedPath
            } else {
                fileUrl = "file:///" + normalizedPath
            }
            alertPlayer.source = fileUrl
            alertPlayer.play()
        }
    }

    MediaPlayer {
        id: alertPlayer
        audioOutput: AudioOutput { volume: 1.0 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            height: 4
            color: alertRoot.alertColor
            radius: 2
        }

        Label {
            text: alertRoot.alertTitle
            font.pixelSize: 18
            font.bold: true
            color: alertRoot.alertColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        
            ScrollBar.vertical: ScrollBar {
                width: 10
        
                contentItem: Rectangle {
                    implicitWidth: 10
                    radius: 5
                    color: "#666666"
                }
        
                background: Rectangle {
                    color: "#1e1e1e"
                }
            }
        
            Text {
                width: parent.width
                text: alertRoot.alertDescription
                color: "#ccc"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
        }

        Label {
            text: "Expires: " + alertRoot.alertExpiry
            font.pixelSize: 11
            color: "#888"
            visible: alertRoot.alertExpiry !== ""
        }

        Button {
            text: "Dismiss"
            Layout.alignment: Qt.AlignRight
            onClicked: {
                alertPlayer.stop()
                alertRoot.dismiss()
            }
        }
    }
}
