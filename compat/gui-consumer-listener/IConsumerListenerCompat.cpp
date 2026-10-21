#include "include/IConsumerListenerCompat.h"

#include <gui/BufferItem.h>
#include <utils/Log.h>

namespace android {

namespace {

enum class Tag : uint32_t {
    ON_DISCONNECT = IBinder::FIRST_CALL_TRANSACTION,
    ON_FRAME_AVAILABLE,
    ON_FRAME_REPLACED,
    ON_BUFFERS_RELEASED,
    ON_SIDEBAND_STREAM_CHANGED,
    ON_FRAME_DEQUEUED,
    ON_FRAME_CANCELLED,
    ON_FRAME_DETACHED,
    ON_SLOT_COUNT_CHANGED,
    LAST = ON_SLOT_COUNT_CHANGED,
};

} // namespace

class BpConsumerListener : public SafeBpInterface<IConsumerListener> {
public:
    explicit BpConsumerListener(const sp<IBinder>& impl)
          : SafeBpInterface<IConsumerListener>(impl, "BpConsumerListener") {}

    ~BpConsumerListener() override;

    void onDisconnect() override {
        callRemoteAsync<decltype(&IConsumerListener::onDisconnect)>(Tag::ON_DISCONNECT);
    }

    void onFrameDequeued(const uint64_t bufferId) override {
        callRemoteAsync<decltype(&IConsumerListener::onFrameDequeued)>(Tag::ON_FRAME_DEQUEUED,
                                                                       bufferId);
    }

    void onFrameDetached(const uint64_t bufferId) override {
        callRemoteAsync<decltype(&IConsumerListener::onFrameDetached)>(Tag::ON_FRAME_DETACHED,
                                                                       bufferId);
    }

    void onFrameCancelled(const uint64_t bufferId) override {
        callRemoteAsync<decltype(&IConsumerListener::onFrameCancelled)>(Tag::ON_FRAME_CANCELLED,
                                                                        bufferId);
    }

    void onFrameAvailable(const BufferItem& item) override {
        callRemoteAsync<decltype(&IConsumerListener::onFrameAvailable)>(Tag::ON_FRAME_AVAILABLE,
                                                                        item);
    }

    void onFrameReplaced(const BufferItem& item) override {
        callRemoteAsync<decltype(&IConsumerListener::onFrameReplaced)>(Tag::ON_FRAME_REPLACED,
                                                                       item);
    }

    void onBuffersReleased() override {
        callRemoteAsync<decltype(&IConsumerListener::onBuffersReleased)>(Tag::ON_BUFFERS_RELEASED);
    }

    void onSidebandStreamChanged() override {
        callRemoteAsync<decltype(&IConsumerListener::onSidebandStreamChanged)>(
                Tag::ON_SIDEBAND_STREAM_CHANGED);
    }

    void addAndGetFrameTimestamps(const NewFrameEventsEntry*,
                                  FrameEventHistoryDelta*) override {
        LOG_ALWAYS_FATAL("IConsumerListener::addAndGetFrameTimestamps cannot be proxied");
    }

    void onSlotCountChanged(int slotCount) override {
        callRemoteAsync<decltype(&IConsumerListener::onSlotCountChanged)>(
                Tag::ON_SLOT_COUNT_CHANGED, slotCount);
    }
};

BpConsumerListener::~BpConsumerListener() = default;

IMPLEMENT_META_INTERFACE(ConsumerListener, "android.gui.IConsumerListener");

status_t BnConsumerListener::onTransact(uint32_t code, const Parcel& data, Parcel* reply,
                                        uint32_t flags) {
    if (code < IBinder::FIRST_CALL_TRANSACTION || code > static_cast<uint32_t>(Tag::LAST)) {
        return BBinder::onTransact(code, data, reply, flags);
    }

    switch (static_cast<Tag>(code)) {
        case Tag::ON_DISCONNECT:
            return callLocalAsync(data, reply, &IConsumerListener::onDisconnect);
        case Tag::ON_FRAME_AVAILABLE:
            return callLocalAsync(data, reply, &IConsumerListener::onFrameAvailable);
        case Tag::ON_FRAME_REPLACED:
            return callLocalAsync(data, reply, &IConsumerListener::onFrameReplaced);
        case Tag::ON_BUFFERS_RELEASED:
            return callLocalAsync(data, reply, &IConsumerListener::onBuffersReleased);
        case Tag::ON_SIDEBAND_STREAM_CHANGED:
            return callLocalAsync(data, reply, &IConsumerListener::onSidebandStreamChanged);
        case Tag::ON_FRAME_DEQUEUED:
            return callLocalAsync(data, reply, &IConsumerListener::onFrameDequeued);
        case Tag::ON_FRAME_CANCELLED:
            return callLocalAsync(data, reply, &IConsumerListener::onFrameCancelled);
        case Tag::ON_FRAME_DETACHED:
            return callLocalAsync(data, reply, &IConsumerListener::onFrameDetached);
        case Tag::ON_SLOT_COUNT_CHANGED:
            return callLocalAsync(data, reply, &IConsumerListener::onSlotCountChanged);
    }
}

} // namespace android
