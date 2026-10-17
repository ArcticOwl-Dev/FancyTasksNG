// SPDX-License-Identifier: GPL-2.0-or-later
#include "Region.h"
#include "IconIdentity.h"
#include <QQmlExtensionPlugin>
#include <QGuiApplication>
#include <QEvent>
#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QWindow>
#include <QMetaProperty>
#include <qqml.h>

class WindowRegion : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool wayland READ wayland CONSTANT)
    Q_PROPERTY(bool dodgeActive READ dodgeActive NOTIFY anchorStateChanged)
public:
    using QObject::QObject;
    bool wayland() const { return QGuiApplication::platformName().startsWith(QStringLiteral("wayland")); }
    bool dodgeActive() const
    {
        // PanelView::DodgeWindows is 2. Reuse the debounced overlap state
        // that Plasma itself uses, without another window model or timer.
        return m_anchorWindow && m_anchorWindow->property("visibilityMode").toInt() == 2
            && m_panelRoot && m_panelRoot->property("touchingWindow").toBool();
    }

    Q_INVOKABLE bool observeAnchor(QQuickItem *anchor)
    {
        if (!anchor) return false;
        // At Plasma startup the applet can complete before it has a window.
        // Subscribe now: windowChanged will reconnect when the panel is ready.
        watchAnchor(anchor);
        Q_EMIT anchorStateChanged();
        return true;
    }

    Q_INVOKABLE bool panelContainsPointer() const
    {
        // Wayland's QCursor::pos() is only the last position delivered to this
        // client. After leaving Plasma it can remain inside the panel forever.
        // Window enter/leave events describe actual pointer ownership instead.
        return m_anchorWindow && m_panelPointerInside;
    }

    Q_INVOKABLE bool apply(QObject *object, const QVariantList &rectangles)
    {
        auto window = qobject_cast<QWindow *>(object);
        if (!window) return false;
        if (m_window != window) {
            if (m_window) m_window->removeEventFilter(this);
            QObject::disconnect(m_frameConnection);
            m_window = window;
            window->installEventFilter(this);
            if (auto quick = qobject_cast<QQuickWindow *>(window)) {
                m_frameConnection = connect(quick, &QQuickWindow::afterAnimating, this, [this]() {
                    Q_EMIT frameReady();
                    restoreMask();
                });
            }
        }
        const QRegion region = inputRegion(rectangles);
        m_region = region;
        if (window->mask() != region) window->setMask(region);
        return window->mask() == region;
    }

    Q_INVOKABLE void position(QObject *object, QQuickItem *anchor, const QPointF &offset)
    {
        auto window = qobject_cast<QWindow *>(object);
        if (window && anchor && anchor->window()) {
            if (!window->parent() && window->screen() != anchor->window()->screen()) window->setScreen(anchor->window()->screen());
            const QPoint pos = anchor->mapToGlobal(offset).toPoint();
            if (window->position() != pos) window->setPosition(pos);
        }
    }

    Q_INVOKABLE bool ownsKeyboardFocus(QObject *object) const
    {
        return qobject_cast<QWindow *>(object) == QGuiApplication::focusWindow();
    }

    Q_INVOKABLE bool anchorVisible(QQuickItem *anchor) const
    {
        if (!anchor || !anchor->isVisible() || !anchor->window()) return false;
        const auto window = anchor->window();
        if (!window->isVisible() || !window->isExposed() || !window->screen()) return false;
        return QRectF(anchor->mapToGlobal(QPointF()), anchor->size())
            .intersects(QRectF(window->screen()->geometry()));
    }
    Q_INVOKABLE QRectF screenGeometry(QQuickItem *anchor) const
    {
        return anchor && anchor->window() && anchor->window()->screen()
            ? QRectF(anchor->window()->screen()->geometry()) : QRectF();
    }
Q_SIGNALS:
    void frameReady();
    void anchorStateChanged();
protected:
    bool eventFilter(QObject *object, QEvent *event) override
    {
        if (object == m_anchorWindow) {
            if (event->type() == QEvent::Enter) m_panelPointerInside = true;
            else if (event->type() == QEvent::Leave || event->type() == QEvent::Hide) m_panelPointerInside = false;
        }
        if (object == m_anchorWindow && (event->type() == QEvent::Expose || event->type() == QEvent::Show
            || event->type() == QEvent::Hide || event->type() == QEvent::Move || event->type() == QEvent::Resize
            || event->type() == QEvent::Enter || event->type() == QEvent::Leave)) {
            Q_EMIT anchorStateChanged();
        }
        // Plasma can clear a dialog's mask during theme/size changes. Restore
        // our input region before the next frame is committed to Wayland.
        if (object == m_window && (event->type() == QEvent::UpdateRequest || event->type() == QEvent::Expose)) {
            restoreMask();
        }
        return false;
    }
private:
    void watchProperty(QObject *object, const char *name)
    {
        const int index = object->metaObject()->indexOfProperty(name);
        if (index < 0) return;
        const auto property = object->metaObject()->property(index);
        if (property.hasNotifySignal()) {
            m_anchorConnections << connect(object, property.notifySignal(), this,
                metaObject()->method(metaObject()->indexOfSignal("anchorStateChanged()")));
        }
    }
    void watchAnchor(QQuickItem *anchor)
    {
        for (const auto &connection : m_anchorConnections) QObject::disconnect(connection);
        m_anchorConnections.clear();
        if (m_anchorWindow) m_anchorWindow->removeEventFilter(this);
        m_anchor = anchor;
        const auto window = anchor ? anchor->window() : nullptr;
        if (m_anchorWindow != window) m_panelPointerInside = false;
        m_anchorWindow = window;
        m_panelRoot = nullptr;
        for (auto item = anchor; item; item = item->parentItem()) {
            if (item->metaObject()->indexOfProperty("touchingWindow") >= 0) {
                m_panelRoot = item;
                watchProperty(item, "touchingWindow");
            }
            m_anchorConnections << connect(item, &QQuickItem::xChanged, this, &WindowRegion::anchorStateChanged)
                << connect(item, &QQuickItem::yChanged, this, &WindowRegion::anchorStateChanged)
                << connect(item, &QQuickItem::widthChanged, this, &WindowRegion::anchorStateChanged)
                << connect(item, &QQuickItem::heightChanged, this, &WindowRegion::anchorStateChanged)
                << connect(item, &QQuickItem::visibleChanged, this, &WindowRegion::anchorStateChanged)
                << connect(item, &QQuickItem::windowChanged, this, &WindowRegion::reconnectAnchor)
                << connect(item, &QQuickItem::parentChanged, this, &WindowRegion::reconnectAnchor);
        }
        if (m_anchorWindow) {
            watchProperty(m_anchorWindow, "visibilityMode");
            m_anchorWindow->installEventFilter(this);
            m_anchorConnections << connect(m_anchorWindow, &QQuickWindow::afterAnimating, this, &WindowRegion::notifyAnchorState)
                << connect(m_anchorWindow, &QWindow::visibleChanged, this, &WindowRegion::anchorStateChanged)
                << connect(m_anchorWindow, &QWindow::screenChanged, this, &WindowRegion::anchorStateChanged);
        }
    }
    void reconnectAnchor()
    {
        watchAnchor(m_anchor);
        Q_EMIT anchorStateChanged();
    }
    void notifyAnchorState()
    {
        const QRectF bounds = m_anchor ? QRectF(m_anchor->mapToGlobal(QPointF()), m_anchor->size()) : QRectF();
        const bool visible = anchorVisible(m_anchor);
        if (bounds == m_anchorBounds && visible == m_anchorVisible) return;
        m_anchorBounds = bounds;
        m_anchorVisible = visible;
        Q_EMIT anchorStateChanged();
    }
    void restoreMask()
    {
        if (m_window && m_window->mask() != m_region) m_window->setMask(m_region);
    }
    QPointer<QWindow> m_window;
    QRegion m_region;
    QMetaObject::Connection m_frameConnection;
    QPointer<QQuickItem> m_panelRoot;
    QPointer<QQuickItem> m_anchor;
    QPointer<QQuickWindow> m_anchorWindow;
    QList<QMetaObject::Connection> m_anchorConnections;
    QRectF m_anchorBounds;
    bool m_anchorVisible = false;
    bool m_panelPointerInside = false;
};

class Plugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")
public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<WindowRegion>(uri, 1, 0, "WindowRegion");
        qmlRegisterType<IconIdentity>(uri, 1, 0, "IconIdentity");
    }
};

#include "WindowRegion.moc"
