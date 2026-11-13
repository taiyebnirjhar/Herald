package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RoutesTest {
    @Test
    fun everyRouteSurvivesARoundTrip() {
        for (route in listOf(Routes.SETUP, Routes.JOBS, Routes.CHAT)) {
            assertEquals(route, Routes.parse(route))
        }
    }

    @Test
    fun theRouteNamesAreTheOnesTheDartSideExpects() {
        assertEquals("setup", Routes.SETUP)
        assertEquals("jobs", Routes.JOBS)
        assertEquals("chat", Routes.CHAT)
    }

    @Test
    fun anUnknownRouteGivesNull() {
        assertNull(Routes.parse("settings"))
        assertNull(Routes.parse("Jobs"))
        assertNull(Routes.parse(" jobs"))
        assertNull(Routes.parse(""))
    }

    @Test
    fun aMissingRouteGivesNull() {
        assertNull(Routes.parse(null))
    }

    @Test
    fun theExtraNameIsHeraldRoute() {
        assertEquals("herald.route", Routes.EXTRA)
    }
}
