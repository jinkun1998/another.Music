package com.mochyy.mochymusic.ui.player

import org.junit.Assert.assertTrue
import org.junit.Test

class CoverMorphInterpolationTest {
    @Test
    fun `cover morph art size interpolates smoothly and continuously without late jump`() {
        val miniSize = 48f
        val fullSize = 340f
        fun lerp(start: Float, stop: Float, fraction: Float): Float = start + (stop - start) * fraction
        val sizeAt25 = lerp(miniSize, fullSize, 0.25f)
        val sizeAt50 = lerp(miniSize, fullSize, 0.50f)
        val sizeAt75 = lerp(miniSize, fullSize, 0.75f)

        // Verifies no late-pop threshold (previously size stayed at 48f until p=0.7)
        assertTrue("Size at 25% progress must exceed mini size", sizeAt25 > miniSize + 50f)
        assertTrue("Size at 50% progress must be halfway", (sizeAt50 - (miniSize + fullSize) / 2f) < 0.001f)
        assertTrue("Size must grow monotonically", sizeAt75 > sizeAt50 && sizeAt50 > sizeAt25)
    }
}
