import android.graphics.Bitmap;
import android.graphics.Gainmap;
import android.graphics.ImageDecoder;
import java.io.File;
import java.util.Arrays;

public final class CameraHdrDecodeProbe {
    public static void main(String[] args) throws Exception {
        Bitmap image = ImageDecoder.decodeBitmap(ImageDecoder.createSource(new File(args[0])),
            (decoder, info, source) -> decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE));
        try {
            System.out.println("DECODE width=" + image.getWidth() + " height=" + image.getHeight()
                + " hasGainmap=" + image.hasGainmap());
            if (image.hasGainmap()) {
                Gainmap gain = image.getGainmap();
                System.out.println("GAINMAP width=" + gain.getGainmapContents().getWidth()
                    + " height=" + gain.getGainmapContents().getHeight()
                    + " ratioMin=" + Arrays.toString(gain.getRatioMin())
                    + " ratioMax=" + Arrays.toString(gain.getRatioMax())
                    + " fullHdrRatio=" + gain.getDisplayRatioForFullHdr());
                Bitmap pixels = gain.getGainmapContents();
                int first = pixels.getPixel(0, 0), differing = 0;
                for (int y = 0; y < 32; ++y) for (int x = 0; x < 32; ++x) {
                    int pixel = pixels.getPixel(x * (pixels.getWidth() - 1) / 31,
                        y * (pixels.getHeight() - 1) / 31);
                    if (pixel != first) ++differing;
                }
                System.out.println("GAINMAP config=" + pixels.getConfig()
                    + " differingSamples=" + differing + "/1024");
            }
        } finally { image.recycle(); }
    }
}
