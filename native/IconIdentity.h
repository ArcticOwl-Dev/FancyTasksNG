// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QIcon>
#include <QObject>
#include <QVariant>

class IconIdentity : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE QString identity(const QVariant &decoration) const
    {
        // Plasma supplies QIcon values; custom bitmap icons may have no name.
        if (decoration.canConvert<QIcon>()) return qvariant_cast<QIcon>(decoration).name();
        if (decoration.metaType() == QMetaType::fromType<QString>()) return decoration.toString();
        return {};
    }
};
