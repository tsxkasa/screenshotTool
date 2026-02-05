pragma Singleton
import QtQuick

QtObject {
    function saveItem(item, path, rect, callback) {
        item.grabToImage(function (result) {
            result.saveToFile(path);
            if (callback) {
                callback(path);
            }
        });
    }
}
