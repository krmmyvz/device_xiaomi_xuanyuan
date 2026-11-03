/*
 * Switches the panel into its hardware AOD mode while the screen dozes.
 *
 * The mi_disp driver writes doze_brightness = 1 (high, HBM) itself when the panel enters AOD.
 * Stock switches it to 2 (low, LBM) in the dark from MIUI, but the xiaomi.sensor.aod events are
 * not a reliable doze signal here, so this service no longer touches that node.
 *
 * It also turns on the touch IC double tap gesture (touchfeature mode 14), which stock enables
 * from MIUI settings; without it xiaomi.sensor.dbtap never fires for double tap to wake.
 */

#define LOG_TAG "xiaomi-aod-notifier"

#include <aidl/android/frameworks/sensorservice/BnEventQueueCallback.h>
#include <aidl/android/frameworks/sensorservice/ISensorManager.h>
#include <android-base/file.h>
#include <android-base/logging.h>
#include <android/binder_ibinder.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <string>

using aidl::android::frameworks::sensorservice::BnEventQueueCallback;
using aidl::android::frameworks::sensorservice::IEventQueue;
using aidl::android::frameworks::sensorservice::ISensorManager;
using aidl::android::hardware::sensors::Event;
using aidl::android::hardware::sensors::SensorInfo;

namespace {

constexpr char kAodSensorType[] = "xiaomi.sensor.aod";

constexpr char kTouchFeatureInstance[] = "vendor.xiaomi.hw.touchfeature.ITouchFeature/default";
constexpr char kTouchFeatureDescriptor[] = "vendor.xiaomi.hw.touchfeature.ITouchFeature";
// ITouchFeature.setTouchMode(int touchId, int mode, int value) is the 9th method.
constexpr transaction_code_t kSetTouchMode = FIRST_CALL_TRANSACTION + 8;
constexpr int32_t kTouchDoubleTapMode = 14;

void* onCreate(void* args) {
    return args;
}
void onDestroy(void*) {}
binder_status_t onTransact(AIBinder*, transaction_code_t, const AParcel*, AParcel*) {
    return STATUS_UNKNOWN_TRANSACTION;
}

// Calls setTouchMode without the generated stubs, whose library name clashes with the stock one.
void enableDoubleTapGesture() {
    static AIBinder_Class* clazz =
            AIBinder_Class_define(kTouchFeatureDescriptor, onCreate, onDestroy, onTransact);
    ndk::SpAIBinder binder(AServiceManager_checkService(kTouchFeatureInstance));
    if (binder.get() == nullptr || !AIBinder_associateClass(binder.get(), clazz)) {
        LOG(WARNING) << "touchfeature unavailable";
        return;
    }
    AParcel* in = nullptr;
    if (AIBinder_prepareTransaction(binder.get(), &in) != STATUS_OK) return;
    AParcel_writeInt32(in, 0);
    AParcel_writeInt32(in, kTouchDoubleTapMode);
    AParcel_writeInt32(in, 1);
    AParcel* out = nullptr;
    binder_status_t status = AIBinder_transact(binder.get(), kSetTouchMode, &in, &out, 0);
    if (status != STATUS_OK) LOG(WARNING) << "setTouchMode failed: " << status;
    AParcel_delete(out);
}

float eventValue(const Event& event) {
    switch (event.payload.getTag()) {
        case Event::EventPayload::scalar:
            return event.payload.get<Event::EventPayload::scalar>();
        case Event::EventPayload::data:
            return event.payload.get<Event::EventPayload::data>().values[0];
        default:
            return -1;
    }
}

// doze_brightness'a artik yazmiyoruz. Sensor hub'in doze olayi (4) ekran acikken de geliyor ve
// dugum uyanista sifirlanmiyor; acik ekranda LBM (2) yazmak paneli aniden kisiyordu. Guvenilir bir
// doze sinyali olmadan AOD parlakligi cekirdegin varsayilaninda (HBM) kaliyor.
class AodCallback : public BnEventQueueCallback {
  public:
    ndk::ScopedAStatus onEvent(const Event& event) override {
        LOG(INFO) << "aod event " << static_cast<int>(eventValue(event));
        enableDoubleTapGesture();
        return ndk::ScopedAStatus::ok();
    }
};

}  // namespace

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(1);
    ABinderProcess_startThreadPool();

    const std::string instance = std::string(ISensorManager::descriptor) + "/default";
    auto manager = ISensorManager::fromBinder(
            ndk::SpAIBinder(AServiceManager_waitForService(instance.c_str())));
    if (!manager) {
        LOG(ERROR) << "no " << instance;
        return 1;
    }

    std::vector<SensorInfo> sensors;
    if (!manager->getSensorList(&sensors).isOk()) {
        LOG(ERROR) << "getSensorList failed";
        return 1;
    }
    int32_t handle = -1;
    for (const auto& sensor : sensors) {
        if (sensor.typeAsString == kAodSensorType &&
            (sensor.flags & SensorInfo::SENSOR_FLAG_BITS_WAKE_UP)) {
            handle = sensor.sensorHandle;
            break;
        }
    }
    if (handle < 0) {
        LOG(ERROR) << "no wakeup " << kAodSensorType << " sensor";
        return 1;
    }

    std::shared_ptr<IEventQueue> queue;
    auto callback = ndk::SharedRefBase::make<AodCallback>();
    if (!manager->createEventQueue(callback, &queue).isOk() ||
        !queue->enableSensor(handle, 0 /* samplingPeriodUs */, 0 /* maxBatchReportLatencyUs */)
                 .isOk()) {
        LOG(ERROR) << "failed to enable " << kAodSensorType;
        return 1;
    }
    LOG(INFO) << "listening on " << kAodSensorType << " (handle " << handle << ")";
    enableDoubleTapGesture();

    ABinderProcess_joinThreadPool();
    return 1;
}
