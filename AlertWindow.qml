import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

ApplicationWindow {
    id: alertRoot

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
            alertPlayer.source = "file://" + alertSoundPath
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
