package com.mochyy.mochymusic.ui.player

import com.mochyy.mochymusic.ui.player.customize.coverArtBoxF
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlayerCoverLayoutTest {
    @Test
    fun `boxed cover on phone portrait stays within region`() {
        val box = coverArtBoxF(boxed = true, width = 390f, height = 844f, statusTop = 32f, unit = 1f)
        val region = 844f * 0.63f
        assertEquals(342f, box.width, 0.001f)
        assertEquals(342f, box.height, 0.001f)
        assertTrue(box.y + box.height <= region)
    }

    @Test
    fun `boxed cover on foldable unfolded portrait clamps to region without overlapping controls`() {
        val box = coverArtBoxF(boxed = true, width = 690f, height = 828f, statusTop = 32f, unit = 1f)
        val region = 828f * 0.63f
        val maxAllowed = region - (32f + 16f) - 8f
        assertEquals(maxAllowed, box.width, 0.01f)
        assertEquals(maxAllowed, box.height, 0.01f)
        assertTrue("Cover bottom (${box.y + box.height}) must not exceed region ($region)", box.y + box.height <= region)
    }

    @Test
    fun `turntable on wide viewport scales width to fit height`() {
        val width = 690f
        val height = 521f
        val turntableWidth = minOf(width, height * 0.75f)
        assertTrue(turntableWidth < width)
        assertTrue(turntableWidth * 1.406f <= height * 1.06f)
    }

    @Test
    fun `poster circle in landscape leaves space for text on wide viewports`() {
        val w = 828f
        val h = 690f
        val posterH = minOf(h, w * 0.45f)
        val textStart = maxOf(posterH * 1.08f, w * 0.48f)
        val remainingTextWidth = w - textStart - 24f
        assertTrue("Text width ($remainingTextWidth) must exceed 350 on landscape foldable", remainingTextWidth > 350f)
    }

    @Test
    fun `turntable layout mode discriminates mobile and foldable viewports`() {
        org.junit.Assert.assertFalse(isTurntableWideLayout(360))
        org.junit.Assert.assertFalse(isTurntableWideLayout(390))
        org.junit.Assert.assertFalse(isTurntableWideLayout(412))
        org.junit.Assert.assertTrue(isTurntableWideLayout(500))
        org.junit.Assert.assertTrue(isTurntableWideLayout(674))
        org.junit.Assert.assertTrue(isTurntableWideLayout(800))
    }

    @Test
    fun `turntable controls horizontal pills fits on foldable title row`() {
        val pillWidth = 59f
        val pillGap = 11f
        val horizontalPillsWidth = 4 * pillWidth + 3 * pillGap
        assertEquals(269f, horizontalPillsWidth, 0.01f)
        val availableWidth = 600f - 60f - 43f - 28f
        val titleWidth = availableWidth - horizontalPillsWidth
        assertTrue("Title width ($titleWidth) must be positive on wide screens", titleWidth > 150f)
    }

    @Test
    fun `parse full version parses release version with hyphenated build number`() {
        val parsed = com.mochyy.mochymusic.core.updater.parseFullVersion("anotherMusic Android v8.4.0-1 v8.4.0-1")
        assertEquals(8, parsed.major)
        assertEquals(4, parsed.minor)
        assertEquals(0, parsed.patch)
        assertEquals(1, parsed.buildNumber)
    }
}
