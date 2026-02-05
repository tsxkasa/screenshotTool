pragma Singleton
import QtQuick

QtObject {
    property var anim: QtObject {
        property var durations: QtObject {
            property int normal: 400
            property int large: 600
            property int expressiveDefaultSpatial: 500
        }
        property var curves: QtObject {
            property var standard: [0.05, 0.7, 0.1, 1, 1, 1]
            property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        }
    }
}
