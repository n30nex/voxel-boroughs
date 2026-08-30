// Voxel Boroughs strategy camera tests
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "test.h"

#include "client/strategy_camera.h"

class TestStrategyCamera : public TestBase
{
public:
	TestStrategyCamera() { TestManager::registerTestModule(this); }
	const char *getName() override { return "TestStrategyCamera"; }
	void runTests(IGameDef *gamedef) override;

	void testOrbitMath();
	void testZoomBounds();
	void testControlYaw();
};

static TestStrategyCamera g_test_instance;

void TestStrategyCamera::runTests(IGameDef *gamedef)
{
	TEST(testOrbitMath);
	TEST(testZoomBounds);
	TEST(testControlYaw);
}

void TestStrategyCamera::testOrbitMath()
{
	const v3f focus(10.0f, 20.0f, 30.0f);
	const v3f position = StrategyCamera::orbitPosition(focus, 0.0f, 0.0f, 100.0f);
	UASSERT(std::abs(position.X - focus.X) < 0.001f);
	UASSERT(std::abs(position.Y - focus.Y) < 0.001f);
	UASSERT(std::abs(position.Z - 130.0f) < 0.001f);
	UASSERT(std::abs(position.getDistanceFrom(focus) - 100.0f) < 0.001f);
}

void TestStrategyCamera::testZoomBounds()
{
	UASSERT(StrategyCamera::zoomTarget(StrategyCamera::MIN_DISTANCE, 100) ==
		StrategyCamera::MIN_DISTANCE);
	UASSERT(StrategyCamera::zoomTarget(StrategyCamera::MAX_DISTANCE, -100) ==
		StrategyCamera::MAX_DISTANCE);
	UASSERT(StrategyCamera::zoomTarget(100.0f * BS, 1) < 100.0f * BS);
}

void TestStrategyCamera::testControlYaw()
{
	UASSERT(std::abs(StrategyCamera::controlYaw(0.0f) - 180.0f) < 0.001f);
	UASSERT(std::abs(StrategyCamera::controlYaw(225.0f) - 45.0f) < 0.001f);
}

