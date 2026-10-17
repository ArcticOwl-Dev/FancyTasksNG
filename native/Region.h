// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QRectF>
#include <QRegion>
#include <QVariantList>
#include <cmath>

inline QRegion inputRegion(const QVariantList &rectangles)
{
    QRegion region;
    for (const auto &value : rectangles) {
        const QRectF rect = value.toRectF();
        if (rect.isValid() && std::isfinite(rect.x()) && std::isfinite(rect.y())
            && std::isfinite(rect.width()) && std::isfinite(rect.height())) {
            region += rect.toAlignedRect();
        }
    }
    // QWindow treats an empty mask as full-window input. An off-window pixel
    // instead gives a mapped surface with no interactive area.
    return region.isEmpty() ? QRegion(QRect(-1, -1, 1, 1)) : region;
}
