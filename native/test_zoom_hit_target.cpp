// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQuickView>
#include <QQuickItem>
#include <QPluginLoader>
#include <QQmlExtensionPlugin>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QEvent>
#include <QEnterEvent>
#include <QCursor>
#include <QtTest>

class PanelFixture : public QQuickWindow
{
    Q_OBJECT
    Q_PROPERTY(int visibilityMode MEMBER mode NOTIFY visibilityModeChanged)
public:
    int mode = 0;
Q_SIGNALS:
    void visibilityModeChanged();
};

class PanelRootFixture : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(bool touchingWindow MEMBER touching NOTIFY touchingWindowChanged)
public:
    using QQuickItem::QQuickItem;
    bool touching = false;
Q_SIGNALS:
    void touchingWindowChanged();
};

class HitTest : public QObject
{
    Q_OBJECT
private slots:
    void panelLeaveOverridesStaleCursorPosition()
    {
        QPluginLoader loader(QStringLiteral(REGION_PLUGIN));
        auto plugin = qobject_cast<QQmlExtensionPlugin *>(loader.instance());
        QVERIFY2(plugin, qPrintable(loader.errorString()));
        plugin->registerTypes("FancyTasksNG.Native");
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData("import FancyTasksNG.Native 1.0\nWindowRegion {}", QUrl());
        QScopedPointer<QObject> bridge(component.create());
        QVERIFY2(bridge, qPrintable(component.errorString()));
        QQuickWindow panel;
        QQuickWindow replacement;
        const QPoint cachedPosition = QCursor::pos();
        panel.setGeometry(QRect(cachedPosition - QPoint(10, 10), QSize(20, 20)));
        QQuickItem anchor(panel.contentItem());
        bool observed = false;
        QVERIFY(QMetaObject::invokeMethod(bridge.data(), "observeAnchor", Q_RETURN_ARG(bool, observed),
            Q_ARG(QQuickItem *, &anchor)));
        QVERIFY(observed);
        const auto pointerInside = [&]() {
            bool inside = false;
            QMetaObject::invokeMethod(bridge.data(), "panelContainsPointer", Q_RETURN_ARG(bool, inside));
            return inside;
        };
        QSignalSpy changed(bridge.data(), SIGNAL(anchorStateChanged()));
        QEnterEvent enter(QPointF(10, 10), QPointF(10, 10), cachedPosition);
        QCoreApplication::sendEvent(&panel, &enter);
        QVERIFY(pointerInside());
        changed.clear();
        QEvent leave(QEvent::Leave);
        QCoreApplication::sendEvent(&panel, &leave);
        QVERIFY(changed.count() > 0);
        QCOMPARE(QCursor::pos(), cachedPosition);
        QVERIFY(panel.geometry().contains(cachedPosition));
        QVERIFY(!pointerInside());

        QCoreApplication::sendEvent(&panel, &enter);
        QVERIFY(pointerInside());
        QEvent hide(QEvent::Hide);
        QCoreApplication::sendEvent(&panel, &hide);
        QVERIFY(!pointerInside());

        QCoreApplication::sendEvent(&panel, &enter);
        anchor.setParentItem(replacement.contentItem());
        QVERIFY(!pointerInside());
        QCoreApplication::sendEvent(&panel, &enter);
        QVERIFY(!pointerInside()); // The previous panel no longer owns this anchor.
        QCoreApplication::sendEvent(&replacement, &enter);
        QVERIFY(pointerInside());
        anchor.setParentItem(nullptr);
    }
    void detachedSurfaceTracksPanelDodgeWithoutPolling()
    {
        QPluginLoader loader(QStringLiteral(REGION_PLUGIN));
        auto plugin = qobject_cast<QQmlExtensionPlugin *>(loader.instance());
        QVERIFY2(plugin, qPrintable(loader.errorString()));
        plugin->registerTypes("FancyTasksNG.Native");
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData("import FancyTasksNG.Native 1.0\nWindowRegion {}", QUrl());
        QScopedPointer<QObject> bridge(component.create());
        QVERIFY2(bridge, qPrintable(component.errorString()));
        PanelFixture panel;
        panel.setPosition(100, 200);
        QWindow child;
        PanelRootFixture container(panel.contentItem());
        QQuickItem anchor;
        container.setPosition(QPointF(10, 20));
        anchor.setPosition(QPointF(30, 40));
        bool observed = false;
        QVERIFY(QMetaObject::invokeMethod(bridge.data(), "observeAnchor", Q_RETURN_ARG(bool, observed),
            Q_ARG(QQuickItem *, &anchor)));
        QVERIFY(observed);
        QVERIFY(!child.parent());
        QVERIFY(!child.transientParent());
        QSignalSpy changed(bridge.data(), SIGNAL(anchorStateChanged()));
        // Saved overlay settings are applied before Plasma attaches the applet
        // to its panel window. This must recover without toggling the setting.
        anchor.setParentItem(&container);
        QVERIFY(changed.count() > 0);
        changed.clear();
        container.setX(11);
        QCOMPARE(changed.count(), 1);
        const QPointF offset(-5, -6);
        QVERIFY(QMetaObject::invokeMethod(bridge.data(), "position", Q_ARG(QObject *, &child),
            Q_ARG(QQuickItem *, &anchor), Q_ARG(QPointF, offset)));
        QCOMPARE(child.position(), QPoint(136, 254));
        QVERIFY(!bridge->property("dodgeActive").toBool());
        changed.clear();
        container.setProperty("touchingWindow", true);
        QVERIFY(changed.count() > 0);
        QVERIFY(!bridge->property("dodgeActive").toBool()); // Always-visible panel.
        changed.clear();
        panel.setProperty("visibilityMode", 2);
        QVERIFY(changed.count() > 0);
        QVERIFY(bridge->property("dodgeActive").toBool());
        container.setProperty("touchingWindow", false);
        QVERIFY(!bridge->property("dodgeActive").toBool());
        container.setProperty("touchingWindow", true);
        panel.setProperty("visibilityMode", 3); // Windows go below: no dodge.
        QVERIFY(!bridge->property("dodgeActive").toBool());
        changed.clear();
        container.setVisible(false);
        QVERIFY(changed.count() > 0);
    }
    void inputMaskSurvivesDialogReset()
    {
        QPluginLoader loader(QStringLiteral(REGION_PLUGIN));
        auto plugin = qobject_cast<QQmlExtensionPlugin *>(loader.instance());
        QVERIFY2(plugin, qPrintable(loader.errorString()));
        plugin->registerTypes("FancyTasksNG.Native");
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData("import FancyTasksNG.Native 1.0\nWindowRegion {}", QUrl());
        QScopedPointer<QObject> bridge(component.create());
        QVERIFY2(bridge, qPrintable(component.errorString()));
        QWindow window;
        const QVariantList rectangles = {QRectF(10, 20, 40, 40)};
        bool applied = false;
        QVERIFY(QMetaObject::invokeMethod(bridge.data(), "apply", Q_RETURN_ARG(bool, applied),
            Q_ARG(QObject *, &window), Q_ARG(QVariantList, rectangles)));
        QVERIFY(applied);
        QCOMPARE(window.mask(), QRegion(QRect(10, 20, 40, 40)));
        window.setMask(QRegion());
        QEvent frame(QEvent::UpdateRequest);
        QCoreApplication::sendEvent(&window, &frame);
        QCOMPARE(window.mask(), QRegion(QRect(10, 20, 40, 40)));
    }
    void enlargedIconReceivesPointerEvents()
    {
        QQuickView view;
        view.setSource(QUrl::fromLocalFile(QStringLiteral(HIT_FIXTURE)));
        QCOMPARE(view.status(), QQuickView::Ready);
        view.show();
        QVERIFY(QTest::qWaitForWindowExposed(&view));
        auto root = view.rootObject();
        // Above and left of the unzoomed button, inside the enlarged icon.
        QTest::mouseMove(&view, QPoint(95, 90));
        QTRY_VERIFY(root->property("hovered").toBool());
        QTest::mouseClick(&view, Qt::LeftButton, Qt::NoModifier, QPoint(95, 90));
        QCOMPARE(root->property("clicks").toInt(), 1);
        QTest::mouseMove(&view, QPoint(40, 40));
        QTRY_VERIFY(!root->property("hovered").toBool());
        QTest::mouseClick(&view, Qt::LeftButton, Qt::NoModifier, QPoint(40, 40));
        QCOMPARE(root->property("clicks").toInt(), 1);
    }
};
QTEST_MAIN(HitTest)
#include "test_zoom_hit_target.moc"
