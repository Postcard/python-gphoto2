// python-gphoto2 - Python interface to libgphoto2
// http://github.com/jim-easterbrook/python-gphoto2
// Copyright (C) 2014-15  Jim Easterbrook  jim@jim-easterbrook.me.uk
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

%module(package="gphoto2") gphoto2_widget

%{
#include "gphoto2/gphoto2.h"
%}

%import "gphoto2_camera.i"
%import "gphoto2_context.i"

%feature("autodoc", "2");

%include "typemaps.i"

%include "macros.i"

IMPORT_GPHOTO2_ERROR()

%rename(CameraWidget) _CameraWidget;

%apply int *OUTPUT { CameraWidgetType * };
%apply int *OUTPUT { int * };
%apply float *OUTPUT { float * };

%typemap(in, numinputs=0) CameraWidget ** (CameraWidget *temp) {
  temp = NULL;
  $1 = &temp;
}
%typemap(argout) CameraWidget ** {
  if (*$1 != NULL) {
    // Increment refcount on root widget
    CameraWidget *root;
    int error = gp_widget_get_root(*$1, &root);
    if (error < GP_OK) {
      GPHOTO2_ERROR(error);
      SWIG_fail;
    }
    error = gp_widget_ref(root);
    if (error < GP_OK) {
      GPHOTO2_ERROR(error);
      SWIG_fail;
    }
  }
  // Append result to output object
  $result = SWIG_Python_AppendOutput(
    $result, SWIG_NewPointerObj(*$1, $*1_descriptor, SWIG_POINTER_OWN));
}

// Union to hold widget value as a void pointer
%{
typedef union {
  float f_val;
  int   i_val;
  char  *s_val;
} widget_value;
%}

// Use typemaps to check/convert input to gp_widget_set_value
%typemap(in) (const void *value)
             (void *argp=0, int res=0, widget_value temp, int alloc=0) {
  // Slightly dodgy use of first argument to get expected type
  CameraWidgetType type;
  int error = gp_widget_get_type(arg1, &type);
  if (error < GP_OK) {
    GPHOTO2_ERROR(error);
    SWIG_fail;
  }
  switch (type) {
    case GP_WIDGET_MENU:
    case GP_WIDGET_TEXT:
    case GP_WIDGET_RADIO:
      temp.s_val = NULL;
      res = SWIG_AsCharPtrAndSize($input, &temp.s_val, NULL, &alloc);
      if (!SWIG_IsOK(res)) {
        SWIG_exception_fail(SWIG_ArgError(res),
          "in method '$symname', argument $argnum of type 'char *'");
      }
      $1 = temp.s_val;
      break;
    case GP_WIDGET_RANGE:
      res = SWIG_AsVal_float($input, &temp.f_val);
      if (!SWIG_IsOK(res)) {
        SWIG_exception_fail(SWIG_ArgError(res),
          "in method '$symname', argument $argnum of type 'float'");
      }
      $1 = &temp;
      break;
    case GP_WIDGET_DATE:
    case GP_WIDGET_TOGGLE:
      res = SWIG_AsVal_int($input, &temp.i_val);
      if (!SWIG_IsOK(res)) {
        SWIG_exception_fail(SWIG_ArgError(res),
          "in method '$symname', argument $argnum of type 'int'");
      }
      $1 = &temp;
      break;
    default:
      SWIG_exception_fail(SWIG_ERROR,
        "in method '$symname', cannot set value of widget");
      break;
  }
}
%typemap(freearg, noblock=1) (const void *value) {
  if (alloc$argnum == SWIG_NEWOBJ)
    free(temp$argnum.s_val);
}
%typemap(argout, noblock=1) (CameraWidget *widget, const void *value),
                            (struct _CameraWidget *self, const void *value) {
}

// Use typemaps to convert result of gp_widget_get_value
%typemap(in, noblock=1, numinputs=0) (void *value) {
  widget_value temp;
  $1 = &temp;
}
%typemap(argout) (CameraWidget *widget, void *value),
                 (struct _CameraWidget *self, void *value) {
  PyObject *py_value;
  CameraWidgetType type;
  int error = gp_widget_get_type($1, &type);
  if (error < GP_OK) {
    GPHOTO2_ERROR(error);
    SWIG_fail;
  }
  switch (type) {
    case GP_WIDGET_MENU:
    case GP_WIDGET_TEXT:
    case GP_WIDGET_RADIO:
      if (temp.s_val)
        py_value = PyString_FromString(temp.s_val);
      else {
        Py_INCREF(Py_None);
        py_value = Py_None;
      }
      break;
    case GP_WIDGET_RANGE:
      py_value = PyFloat_FromDouble(temp.f_val);
      break;
    case GP_WIDGET_DATE:
    case GP_WIDGET_TOGGLE:
      py_value = PyInt_FromLong(temp.i_val);
      break;
    default:
      Py_INCREF(Py_None);
      py_value = Py_None;
  }
  $result = SWIG_Python_AppendOutput($result, py_value);
}

// Add default destructor to _CameraWidget
// Destructor decrefs root widget
%inline %{
static int widget_dtor(CameraWidget *widget) {
  if (widget == NULL)
    return GP_OK;
  {
    CameraWidget *root;
    int error = gp_widget_get_root(widget, &root);
    if (error < GP_OK)
      return error;
    return gp_widget_unref(root);
  }
}
%}
struct _CameraWidget {};
DEFAULT_DTOR(_CameraWidget, widget_dtor)
%ignore _CameraWidget;

// Add member methods to _CameraWidget
INT_MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    count_children, (),
    gp_widget_count_children, ($self))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_child, (int child_number, CameraWidget **child),
    gp_widget_get_child, ($self, child_number, child))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_child_by_label, (const char *label, CameraWidget **child),
    gp_widget_get_child_by_label, ($self, label, child))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_child_by_id, (int id, CameraWidget **child),
    gp_widget_get_child_by_id, ($self, id, child))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_child_by_name, (const char *name, CameraWidget **child),
    gp_widget_get_child_by_name, ($self, name, child))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_root, (CameraWidget **root),
    gp_widget_get_root, ($self, root))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_parent, (CameraWidget **parent),
    gp_widget_get_parent, ($self, parent))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_value, (const void *value),
    gp_widget_set_value, ($self, value))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_value, (void *value),
    gp_widget_get_value, ($self, value))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_name, (const char *name),
    gp_widget_set_name, ($self, name))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_name, (const char **name),
    gp_widget_get_name, ($self, name))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_info, (const char *info),
    gp_widget_set_info, ($self, info))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_info, (const char **info),
    gp_widget_get_info, ($self, info))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_id, (int *id),
    gp_widget_get_id, ($self, id))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_type, (CameraWidgetType *type),
    gp_widget_get_type, ($self, type))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_label, (const char **label),
    gp_widget_get_label, ($self, label))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_range, (float min, float max, float increment),
    gp_widget_set_range, ($self, min, max, increment))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_range, (float *min, float *max, float *increment),
    gp_widget_get_range, ($self, min, max, increment))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    add_choice, (const char *choice),
    gp_widget_add_choice, ($self, choice))
INT_MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    count_choices, (),
    gp_widget_count_choices, ($self))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_choice, (int choice_number, const char **choice),
    gp_widget_get_choice, ($self, choice_number, choice))
INT_MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    changed, (),
    gp_widget_changed, ($self))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_changed, (int changed),
    gp_widget_set_changed, ($self, changed))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    set_readonly, (int readonly),
    gp_widget_set_readonly, ($self, readonly))
MEMBER_FUNCTION(_CameraWidget, CameraWidget,
    get_readonly, (int *readonly),
    gp_widget_get_readonly, ($self, readonly))

// some methods return string pointers in output params
STRING_ARGOUT()

%inline %{
// Add type specific gp_widget_get_value methods
static int gp_widget_get_value_text(CameraWidget *widget, char **value) {
  return gp_widget_get_value(widget, value);
  };

static int gp_widget_get_value_int(CameraWidget *widget, int *value) {
  return gp_widget_get_value(widget, value);
  };

static int gp_widget_get_value_float(CameraWidget *widget, float *value) {
  return gp_widget_get_value(widget, value);
  };

// Add type specific gp_widget_set_value methods
static int gp_widget_set_value_text(CameraWidget *widget, const char *value) {
  return gp_widget_set_value(widget, value);
  };

static int gp_widget_set_value_int(CameraWidget *widget, const int value) {
  return gp_widget_set_value(widget, &value);
  };

static int gp_widget_set_value_float(CameraWidget *widget, const float value) {
  return gp_widget_set_value(widget, &value);
  };
%}

%include "gphoto2/gphoto2-widget.h"
