import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Application

ApplicationWindow {
    id: settingsRoot
    visible: false
    title: "Options"
    width: 350; height: 520
    color: "#1e1e1e"

    ConfigService {
        id: config
    }

    Component.onCompleted: loadUIFromConfig()

    function loadUIFromConfig() {
        var cfg = config.appConfig
        soundEnabledCombo.currentIndex = cfg.alertSound.enabled ? 0 : 1
        minorSoundPath.text = cfg.alertSound.minorPath
        moderateSoundPath.text = cfg.alertSound.moderatePath
        severeSoundPath.text = cfg.alertSound.severePath
        minorSwatch.color = cfg.alertColors.minor || "#FFD700"
        moderateSwatch.color = cfg.alertColors.moderate || "#FF8C00"
        severeSwatch.color = cfg.alertColors.severe || "#FF0000"
        severityMinor.checked = cfg.severities.minor
        severityModerate.checked = cfg.severities.moderate
        severitySevere.checked = cfg.severities.severe
        loadLocationCodes()
    }

    function loadLocationCodes() {
        sameCodeModel.clear()
        capcpCodeModel.clear()
        var sameCsv = config.getSameCodes()
        if (sameCsv !== "") {
            var sameArr = sameCsv.split(",")
            for (var i = 0; i < sameArr.length; i++)
                sameCodeModel.append({ "code": sameArr[i].trim() })
        }
        var capcpCsv = config.getCapcpCodes()
        if (capcpCsv !== "") {
            var capcpArr = capcpCsv.split(",")
            for (var j = 0; j < capcpArr.length; j++)
                capcpCodeModel.append({ "code": capcpArr[j].trim() })
        }
    }

    function applyToConfig() {
        var cfg = config.appConfig
        cfg.alertSound.enabled = soundEnabledCombo.currentIndex === 0
        cfg.alertSound.minorPath = minorSoundPath.text
        cfg.alertSound.moderatePath = moderateSoundPath.text
        cfg.alertSound.severePath = severeSoundPath.text
        cfg.alertColors.minor = minorSwatch.color.toString()
        cfg.alertColors.moderate = moderateSwatch.color.toString()
        cfg.alertColors.severe = severeSwatch.color.toString()
        cfg.severities.minor = severityMinor.checked
        cfg.severities.moderate = severityModerate.checked
        cfg.severities.severe = severitySevere.checked
        var sameArr = []
        for (var i = 0; i < sameCodeModel.count; i++)
            sameArr.push(sameCodeModel.get(i).code)
        config.setSameCodes(sameArr.join(","))
        var capcpArr = []
        for (var j = 0; j < capcpCodeModel.count; j++)
            capcpArr.push(capcpCodeModel.get(j).code)
        config.setCapcpCodes(capcpArr.join(","))
    }

    property string _pendingPathTarget: ""

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            GroupBox {
                title: "Alert Sounds"
                Layout.fillWidth: true
                Layout.margins: 12

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        spacing: 12
                        Label { text: "Sound playback:"; Layout.alignment: Qt.AlignVCenter }
                        ComboBox { id: soundEnabledCombo; model: ["Enabled", "Disabled"]; currentIndex: 0; Layout.preferredWidth: 160 }
                    }

                    RowLayout {
                        spacing: 10
                        visible: soundEnabledCombo.currentIndex === 0
                        Layout.fillWidth: true
                        Label { text: "Minor:"; Layout.preferredWidth: 60 }
                        TextField { id: minorSoundPath; placeholderText: "/path/to/minor.wav"; Layout.fillWidth: true; readOnly: true }
                        Button { text: "Browse..."; onClicked: { _pendingPathTarget = "minor"; soundFileDialog.open() } }
                    }

                    RowLayout {
                        spacing: 10
                        visible: soundEnabledCombo.currentIndex === 0
                        Layout.fillWidth: true
                        Label { text: "Moderate:"; Layout.preferredWidth: 60 }
                        TextField { id: moderateSoundPath; placeholderText: "/path/to/moderate.wav"; Layout.fillWidth: true; readOnly: true }
                        Button { text: "Browse..."; onClicked: { _pendingPathTarget = "moderate"; soundFileDialog.open() } }
                    }

                    RowLayout {
                        spacing: 10
                        visible: soundEnabledCombo.currentIndex === 0
                        Layout.fillWidth: true
                        Label { text: "Severe:"; Layout.preferredWidth: 60 }
                        TextField { id: severeSoundPath; placeholderText: "/path/to/severe.wav"; Layout.fillWidth: true; readOnly: true }
                        Button { text: "Browse..."; onClicked: { _pendingPathTarget = "severe"; soundFileDialog.open() } }
                    }
                }
            }

            GroupBox {
                title: "Location Codes"
                Layout.fillWidth: true
                Layout.margins: 12

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    ColumnLayout {
                        spacing: 6
                        Label { text: "SAME Codes (USA)"; font.bold: true }
                        Label { text: "6-digit FIPS code"; font.pixelSize: 11; color: "#888" }
                        RowLayout {
                            spacing: 8
                            TextField {
                                id: sameCodeInput; placeholderText: "029037"; Layout.preferredWidth: 140
                                validator: RegularExpressionValidator { regularExpression: /^[0-9]{6}$/ }
                            }
                            Button { text: "Add"; onClicked: { var code = sameCodeInput.text.trim(); if (code.length === 0) return; sameCodeModel.append({ "code": code }); sameCodeInput.text = "" } }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 100; color: "#2a2a2a"; border.color: "#ccc"; border.width: 1; radius: 4
                            ListView {
                                id: sameCodeList; anchors.fill: parent; anchors.margins: 4; clip: true; model: ListModel { id: sameCodeModel }
                                delegate: RowLayout { width: sameCodeList.width; spacing: 8
                                    Label { text: code; font.family: "monospace"; Layout.fillWidth: true }
                                    Button { text: "×"; flat: true; onClicked: sameCodeModel.remove(index) }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        Label { text: "CAP-CP Location (Canada)"; font.bold: true }
                        Label { text: "Province/area code (e.g. ON for Ontario)"; font.pixelSize: 11; color: "#888" }
                        RowLayout {
                            spacing: 8
                            TextField { id: capcpCodeInput; placeholderText: "ON"; Layout.preferredWidth: 140 }
                            Button { text: "Add"; onClicked: { var code = capcpCodeInput.text.trim(); if (code.length === 0) return; capcpCodeModel.append({ "code": code }); capcpCodeInput.text = "" } }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 100; color: "#2a2a2a"; border.color: "#ccc"; border.width: 1; radius: 4
                            ListView {
                                id: capcpCodeList; anchors.fill: parent; anchors.margins: 4; clip: true; model: ListModel { id: capcpCodeModel }
                                delegate: RowLayout { width: capcpCodeList.width; spacing: 8
                                    Label { text: code; font.family: "monospace"; Layout.fillWidth: true }
                                    Button { text: "×"; flat: true; onClicked: capcpCodeModel.remove(index) }
                                }
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: "Alert Colours"
                Layout.fillWidth: true
                Layout.margins: 12

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Label { text: "Set a notification colour for each severity level."; font.pixelSize: 11; color: "#888" }

                    RowLayout {
                        spacing: 12
                        Label { text: "Minor"; Layout.preferredWidth: 80 }
                        Rectangle { id: minorSwatch; width: 28; height: 28; radius: 4; border.color: "#999"; border.width: 1; color: "#FFD700"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: minorColorDialog.open() }
                        }
                        Label { text: minorSwatch.color.toString(); font.family: "monospace"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        spacing: 12
                        Label { text: "Moderate"; Layout.preferredWidth: 80 }
                        Rectangle { id: moderateSwatch; width: 28; height: 28; radius: 4; border.color: "#999"; border.width: 1; color: "#FF8C00"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: moderateColorDialog.open() }
                        }
                        Label { text: moderateSwatch.color.toString(); font.family: "monospace"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        spacing: 12
                        Label { text: "Severe"; Layout.preferredWidth: 80 }
                        Rectangle { id: severeSwatch; width: 28; height: 28; radius: 4; border.color: "#999"; border.width: 1; color: "#FF0000"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: severeColorDialog.open() }
                        }
                        Label { text: severeSwatch.color.toString(); font.family: "monospace"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            GroupBox {
                title: "Severity Levels"
                Layout.fillWidth: true
                Layout.margins: 12

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Label { text: "Toggle which severity levels trigger desktop notifications."; font.pixelSize: 11; color: "#888" }
                    CheckBox { id: severityMinor; text: "Minor"; checked: true }
                    CheckBox { id: severityModerate; text: "Moderate"; checked: true }
                    CheckBox { id: severitySevere; text: "Severe"; checked: true }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.margins: 12
                spacing: 10
                Button { text: "Reset Defaults"; onClicked: { console.log("Reset to defaults") } }
                Button { text: "Save"; highlighted: true; onClicked: { applyToConfig(); config.save(); console.log("Settings saved") } }
            }

            Item { Layout.fillHeight: true }
        }
    }

    FileDialog { id: soundFileDialog; title: "Select Alert Sound"; nameFilters: ["Audio files (*.wav *.mp3 *.ogg *.flac)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (Qt.platform.os === "windows") path = path.replace("file:///", ""); else path = path.replace("file://", "")
            if (_pendingPathTarget === "minor") minorSoundPath.text = path
            else if (_pendingPathTarget === "moderate") moderateSoundPath.text = path
            else if (_pendingPathTarget === "severe") severeSoundPath.text = path
        }
    }

    ColorDialog { id: minorColorDialog; title: "Minor Alert Colour"; selectedColor: "#FFD700"; onAccepted: { minorSwatch.color = selectedColor } }
    ColorDialog { id: moderateColorDialog; title: "Moderate Alert Colour"; selectedColor: "#FF8C00"; onAccepted: { moderateSwatch.color = selectedColor } }
    ColorDialog { id: severeColorDialog; title: "Severe Alert Colour"; selectedColor: "#FF0000"; onAccepted: { severeSwatch.color = selectedColor } }
}
