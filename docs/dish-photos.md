# Dish photos

Owners can add a photo to a dish when they create it and change it later from the Menu Dishes tab (camera button).

## What the server accepts

| | |
|---|---|
| Formats | JPEG, PNG, WebP. The type is decided from the file's first bytes, not from its name or the type the client claims, so a text file renamed `.png` is refused (400). |
| Size | 2 MB at most (413 above). The app scales a picked photo to 1600 px and recompresses it first, so ordinary phone photos fit. |
| Who | The dish's restaurant owner or an admin. Another owner gets 403, a customer 403, no sign-in 401. |

`POST /menu-items/{id}/image` (multipart field `file`) returns the dish with its new `imageUrl`; `DELETE /menu-items/{id}/image` removes the photo.

## Where files go

Under `uploads.dir` (env `UPLOADS_DIR`, default `./uploads`), in `dishes/`, named with a random UUID. The client never chooses the file name. The dish stores the path (`/uploads/dishes/<uuid>.jpg`) and the server serves it publicly at that path. Replacing or removing a photo, or deleting the dish, deletes the old file; only files this service named itself can ever be deleted, and links to other sites are left alone.

The app turns a stored path into a full link with the API address (`resolveImageUrl`); search results, menus and carts do this for you, and the dashboard keeps the server's value when it edits a dish.

## Running it for real

Point `UPLOADS_DIR` at a persistent volume. Photos live on that disk, so a host with an ephemeral file system loses them on redeploy; move the storage behind `DishImageService` to object storage if you need that.
