// SPDX-License-Identifier: GPL-2.0-or-later
#include "Region.h"
#include <QtTest>
#include <limits>

class RegionTest : public QObject
{
    Q_OBJECT
private slots:
    void onlyButtonsAcceptInput()
    {
        const auto region = inputRegion({QRectF(10, 40, 40, 40), QRectF(60, 20, 60, 60)});
        QVERIFY(region.contains(QPoint(15, 45)));
        QVERIFY(region.contains(QPoint(65, 25)));
        QVERIFY(!region.contains(QPoint(55, 5)));
        QVERIFY(!region.contains(QPoint(55, 60)));
    }
    void emptyAndInvalidRegionsAreClickThrough()
    {
        QVERIFY(!inputRegion({}).intersects(QRect(0, 0, 400, 200)));
        const auto region = inputRegion({QRectF(), QRectF(0, 0, -1, 50),
            QRectF(std::numeric_limits<double>::quiet_NaN(), 0, 20, 20)});
        QVERIFY(!region.intersects(QRect(0, 0, 400, 200)));
    }
    void fractionalEdgesRoundOutwards()
    {
        const auto region = inputRegion({QRectF(10.5, 20.25, 39.25, 40.5)});
        QCOMPARE(region.boundingRect(), QRect(10, 20, 40, 41));
    }
};
QTEST_MAIN(RegionTest)
#include "test_window_region.moc"
