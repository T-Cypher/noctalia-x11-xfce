pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// [location] resolution (same endpoints as noctalia) and open-meteo forecasts for [weather].
Singleton {
    id: root

    readonly property bool enabled: Config.get("weather.enabled", false) === true && Config.get("shell.offline_mode", false) !== true
    // [weather] unit = "metric" | "imperial" (noctalia's useImperial: unit == "imperial";
    // the legacy "fahrenheit" spelling is accepted too)
    readonly property bool fahrenheit: ["imperial", "fahrenheit"].indexOf(String(Config.get("weather.unit", "metric"))) >= 0
    readonly property int refreshMinutes: Math.max(5, Number(Config.get("weather.refresh_minutes", 30)))

    // location
    property real latitude: NaN
    property real longitude: NaN
    property string locationName: ""
    readonly property bool hasLocation: !isNaN(latitude) && !isNaN(longitude)

    // weather
    property bool loading: false
    property string error: ""
    property var current: null     // {temp, feels, code, isDay, wind, humidity}
    property var daily: []         // [{date, max, min, code}]
    property var hourly: []        // [{time, temp, code, isDay, precip}]
    property real lastUpdate: 0

    readonly property string unitSymbol: fahrenheit ? "°F" : "°C"
    readonly property string locationKey: [Config.get("location.auto_locate", false), Config.get("location.address", ""), Config.get("location.latitude", ""), Config.get("location.longitude", "")].join("|")
    readonly property bool needsLocation: enabled || (Config.get("nightlight.enabled", false) === true && Config.get("location.custom_schedule", false) !== true) || String(Config.get("theme.mode", "dark")) === "auto"

    onLocationKeyChanged: resolveLocation()
    onNeedsLocationChanged: if (needsLocation)
        resolveLocation()
    onEnabledChanged: if (enabled)
        refresh()
    Component.onCompleted: {
        var cached = ShellState.get("location", null);
        if (cached && cached.key === locationKey) {
            latitude = cached.lat;
            longitude = cached.lng;
            locationName = cached.name || "";
        }
        if (needsLocation)
            resolveLocation();
    }

    function get(url, cb) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    cb(JSON.parse(xhr.responseText), null);
                } catch (e) {
                    cb(null, "invalid response");
                }
            } else {
                cb(null, "HTTP " + xhr.status);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function setLocation(lat, lng, name) {
        latitude = lat;
        longitude = lng;
        locationName = name || "";
        ShellState.set("location", {
            key: locationKey,
            lat: lat,
            lng: lng,
            name: locationName
        });
        refresh();
    }

    function resolveLocation() {
        if (Config.get("shell.offline_mode", false) === true)
            return;
        var lat = Number(Config.get("location.latitude", NaN));
        var lng = Number(Config.get("location.longitude", NaN));
        var address = String(Config.get("location.address", ""));
        if (Config.get("location.auto_locate", false) === true) {
            get("https://api.noctalia.dev/geolocate", function (json, err) {
                if (json && json.lat !== undefined)
                    root.setLocation(Number(json.lat), Number(json.lng), [json.city, json.country].filter(x => x).join(", "));
                else
                    root.error = err || "geolocation failed";
            });
        } else if (address.length > 0) {
            get("https://api.noctalia.dev/geocode?city=" + encodeURIComponent(address), function (json, err) {
                if (json && json.lat !== undefined) {
                    root.setLocation(Number(json.lat), Number(json.lng), json.name || address);
                } else {
                    // fallback: open-meteo geocoding
                    root.get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(address.split(",")[0]), function (j2, e2) {
                        if (j2 && j2.results && j2.results.length > 0)
                            root.setLocation(j2.results[0].latitude, j2.results[0].longitude, j2.results[0].name);
                        else
                            root.error = e2 || err || "geocoding failed";
                    });
                }
            });
        } else if (!isNaN(lat) && !isNaN(lng)) {
            setLocation(lat, lng, "");
        }
    }

    function refresh() {
        if (!enabled || !hasLocation || loading)
            return;
        loading = true;
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude.toFixed(4) + "&longitude=" + longitude.toFixed(4) + "&current=temperature_2m,apparent_temperature,wind_speed_10m,weather_code,is_day,relative_humidity_2m" + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day" + "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" + "&forecast_days=7&forecast_hours=24&timezone=auto" + (fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
        get(url, function (json, err) {
            root.loading = false;
            if (!json || !json.current) {
                root.error = err || "weather unavailable";
                return;
            }
            root.error = "";
            var c = json.current;
            root.current = {
                temp: c.temperature_2m,
                feels: c.apparent_temperature,
                code: c.weather_code,
                isDay: c.is_day === 1,
                wind: c.wind_speed_10m,
                humidity: c.relative_humidity_2m
            };
            var d = [];
            if (json.daily && json.daily.time)
                for (var i = 0; i < json.daily.time.length; i++)
                    d.push({
                        date: json.daily.time[i],
                        max: json.daily.temperature_2m_max[i],
                        min: json.daily.temperature_2m_min[i],
                        code: json.daily.weather_code[i],
                        sunrise: json.daily.sunrise ? json.daily.sunrise[i] : "",
                        sunset: json.daily.sunset ? json.daily.sunset[i] : ""
                    });
            root.daily = d;
            var h = [];
            if (json.hourly && json.hourly.time)
                for (var j = 0; j < json.hourly.time.length; j++)
                    h.push({
                        time: json.hourly.time[j],
                        temp: json.hourly.temperature_2m[j],
                        code: json.hourly.weather_code[j],
                        isDay: json.hourly.is_day ? json.hourly.is_day[j] === 1 : true,
                        precip: json.hourly.precipitation_probability ? json.hourly.precipitation_probability[j] : 0
                    });
            root.hourly = h;
            root.lastUpdate = Date.now();
        });
    }

    function glyphFor(code, isDay) {
        if (code === 0)
            return isDay ? "weather-sun" : "weather-moon";
        if (code === 1 || code === 2)
            return isDay ? "weather-cloud-sun" : "weather-moon-stars";
        if (code === 3)
            return "weather-cloud";
        if (code >= 45 && code <= 48)
            return "weather-cloud-haze";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "weather-cloud-rain";
        if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86))
            return "weather-cloud-snow";
        if (code >= 95 && code <= 99)
            return "weather-cloud-lightning";
        return "weather-cloud";
    }

    function describe(code) {
        var key = "weather";
        var fallback = "Weather";
        if (code === 0) {
            key = "clear";
            fallback = "Clear";
        } else if (code === 1) {
            key = "mostly-clear";
            fallback = "Mostly clear";
        } else if (code === 2) {
            key = "cloudy";
            fallback = "Partly cloudy";
        } else if (code === 3) {
            key = "overcast";
            fallback = "Overcast";
        } else if (code === 45 || code === 48) {
            key = "fog";
            fallback = "Fog";
        } else if (code >= 51 && code <= 67) {
            key = "drizzle";
            fallback = "Rain";
        } else if (code >= 71 && code <= 77) {
            key = "snow";
            fallback = "Snow";
        } else if (code >= 80 && code <= 82) {
            key = "showers";
            fallback = "Showers";
        } else if (code >= 85 && code <= 86) {
            key = "snow-showers";
            fallback = "Snow showers";
        } else if (code >= 95 && code <= 99) {
            key = "storm";
            fallback = "Storm";
        }
        return I18n.tr("weather.conditions.short." + key, fallback);
    }

    function temp(v) {
        return v === undefined || v === null ? "--" : Math.round(v) + "°";
    }

    Timer {
        interval: root.refreshMinutes * 60000
        running: root.enabled && root.hasLocation
        repeat: true
        onTriggered: root.refresh()
    }
}
